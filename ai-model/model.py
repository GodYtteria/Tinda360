import math
from dataclasses import dataclass

import torch
import torch.nn as nn
import torch.utils.checkpoint
import torch.nn.functional as F

from linear_attn import GatedDeltaNet


@dataclass
class ModelConfig:
    vocab_size: int = 256
    max_seq_len: int = 256
    d_model: int = 128
    n_layers: int = 4
    n_heads: int = 4
    n_kv_heads: int = 2
    ffn_hidden: int = 344
    rope_theta: float = 10000.0
    norm_eps: float = 1e-6
    tie_embeddings: bool = True
    n_experts: int = 0
    top_k: int = 2
    expert_ffn: int = 0
    aux_coef: float = 0.01
    moe_style: str = "coarse"
    bias_speed: float = 1e-3
    hash_layers: int = 0
    gate_fn: str = "softmax"
    hybrid: int = 0
    lin_heads: int = 6
    lin_head_dim: int = 64
    conv_k: int = 4
    rope_frac: float = 0.25
    mtp: int = 0
    mtp_coef: float = 0.3
    z_loss_coef: float = 1e-3
    seq_balance_coef: float = 1e-4
    route_scale: float = 1.0
    attn_window: int = 0


class RMSNorm(nn.Module):
    def __init__(self, dim, eps):
        super().__init__()
        self.eps = eps
        self.weight = nn.Parameter(torch.ones(dim))

    def forward(self, hidden):
        return hidden * torch.rsqrt(hidden.pow(2).mean(-1, keepdim=True) + self.eps) * self.weight


def rope_cache(head_dim, max_len, theta):
    inv_freq = 1.0 / (theta ** (torch.arange(0, head_dim, 2).float() / head_dim))
    freqs = torch.outer(torch.arange(max_len).float(), inv_freq)
    return freqs.cos(), freqs.sin()


def apply_rope(tensor, cos, sin):
    half1, half2 = tensor.chunk(2, dim=-1)
    cos_full = torch.cat([cos, cos], dim=-1)
    sin_full = torch.cat([sin, sin], dim=-1)
    return tensor * cos_full + torch.cat([-half2, half1], dim=-1) * sin_full


ATTN_CHUNK = int(__import__("os").environ.get("YD_ATTN_CHUNK", "4096"))
LOSS_CHUNK = int(__import__("os").environ.get("YD_LOSS_CHUNK", "8192"))


class Attention(nn.Module):
    def __init__(self, config: ModelConfig):
        super().__init__()
        assert config.d_model % config.n_heads == 0 and config.n_heads % config.n_kv_heads == 0
        self.n_heads, self.n_kv, self.hd = config.n_heads, config.n_kv_heads, config.d_model // config.n_heads
        self.q_proj = nn.Linear(config.d_model, config.n_heads * self.hd, bias=False)
        self.k_proj = nn.Linear(config.d_model, config.n_kv_heads * self.hd, bias=False)
        self.v_proj = nn.Linear(config.d_model, config.n_kv_heads * self.hd, bias=False)
        self.o_proj = nn.Linear(config.n_heads * self.hd, config.d_model, bias=False)

    def forward(self, hidden, cos, sin, cache=None):
        batch_size, seq_len, _ = hidden.shape
        query = self.q_proj(hidden).view(batch_size, seq_len, self.n_heads, self.hd).transpose(1, 2)
        key   = self.k_proj(hidden).view(batch_size, seq_len, self.n_kv,    self.hd).transpose(1, 2)
        value = self.v_proj(hidden).view(batch_size, seq_len, self.n_kv,    self.hd).transpose(1, 2)
        query, key = apply_rope(query, cos, sin), apply_rope(key, cos, sin)
        is_causal = True
        if cache is not None:
            if "k" in cache:
                key   = torch.cat([cache["k"], key],   2)
                value = torch.cat([cache["v"], value], 2)
                is_causal = seq_len > 1
            cache["k"], cache["v"] = key, value
        rep = self.n_heads // self.n_kv
        key   = key.repeat_interleave(rep, dim=1)
        value = value.repeat_interleave(rep, dim=1)
        if is_causal and key.shape[2] != seq_len:
            causal_mask = torch.ones(seq_len, key.shape[2], dtype=torch.bool, device=hidden.device).tril(key.shape[2] - seq_len)
            attended = F.scaled_dot_product_attention(query, key, value, attn_mask=causal_mask)
        elif is_causal and seq_len > ATTN_CHUNK:
            chunks = []
            for start in range(0, seq_len, ATTN_CHUNK):
                end = min(start + ATTN_CHUNK, seq_len)
                chunk_mask = torch.ones(end - start, end, dtype=torch.bool, device=hidden.device).tril(start)
                chunks.append(F.scaled_dot_product_attention(query[:, :, start:end], key[:, :, :end], value[:, :, :end], attn_mask=chunk_mask))
            attended = torch.cat(chunks, dim=2)
        else:
            attended = F.scaled_dot_product_attention(query, key, value, is_causal=is_causal)
        return self.o_proj(attended.transpose(1, 2).reshape(batch_size, seq_len, -1))


class GatedAttention(nn.Module):

    def __init__(self, config: ModelConfig):
        super().__init__()
        self.n_heads, self.n_kv, self.hd = config.n_heads, config.n_kv_heads, config.d_model // config.n_heads
        self.rot = int(self.hd * config.rope_frac)
        self.window = config.attn_window
        self.q_proj = nn.Linear(config.d_model, config.n_heads * self.hd * 2, bias=False)
        self.k_proj = nn.Linear(config.d_model, config.n_kv_heads * self.hd, bias=False)
        self.v_proj = nn.Linear(config.d_model, config.n_kv_heads * self.hd, bias=False)
        self.o_proj = nn.Linear(config.n_heads * self.hd, config.d_model, bias=False)
        self.q_norm = RMSNorm(self.hd, config.norm_eps)
        self.k_norm = RMSNorm(self.hd, config.norm_eps)

    def forward(self, hidden, cos, sin, cache=None):
        batch_size, seq_len, _ = hidden.shape
        query, out_gate = self.q_proj(hidden).view(batch_size, seq_len, self.n_heads, self.hd * 2).chunk(2, -1)
        query = self.q_norm(query).transpose(1, 2)
        key   = self.k_norm(self.k_proj(hidden).view(batch_size, seq_len, self.n_kv, self.hd)).transpose(1, 2)
        value = self.v_proj(hidden).view(batch_size, seq_len, self.n_kv, self.hd).transpose(1, 2)
        rot = self.rot
        query = torch.cat([apply_rope(query[..., :rot], cos, sin), query[..., rot:]], -1)
        key   = torch.cat([apply_rope(key[...,   :rot], cos, sin), key[...,   rot:]], -1)
        is_causal = True
        if cache is not None:
            if "k" in cache:
                key   = torch.cat([cache["k"], key],   2)
                value = torch.cat([cache["v"], value], 2)
                is_causal = seq_len > 1
            if self.window > 0 and key.shape[2] > self.window:
                key, value = key[:, :, -self.window:], value[:, :, -self.window:]
            cache["k"], cache["v"] = key, value
        rep = self.n_heads // self.n_kv
        key   = key.repeat_interleave(rep, dim=1)
        value = value.repeat_interleave(rep, dim=1)
        if is_causal and key.shape[2] != seq_len:
            causal_mask = torch.ones(seq_len, key.shape[2], dtype=torch.bool, device=hidden.device).tril(key.shape[2] - seq_len)
            attended = F.scaled_dot_product_attention(query, key, value, attn_mask=causal_mask)
        else:
            attended = F.scaled_dot_product_attention(query, key, value, is_causal=is_causal)
        gated = attended.transpose(1, 2).reshape(batch_size, seq_len, -1) * torch.sigmoid(out_gate.reshape(batch_size, seq_len, -1))
        return self.o_proj(gated)


SWIGLU_CLAMP = 10.0


class MLP(nn.Module):
    def __init__(self, config: ModelConfig):
        super().__init__()
        self.gate_proj = nn.Linear(config.d_model, config.ffn_hidden, bias=False)
        self.up_proj   = nn.Linear(config.d_model, config.ffn_hidden, bias=False)
        self.down_proj = nn.Linear(config.ffn_hidden, config.d_model, bias=False)

    def forward(self, hidden):
        gate = F.silu(self.gate_proj(hidden)).clamp(max=SWIGLU_CLAMP)
        up   = self.up_proj(hidden).clamp(-SWIGLU_CLAMP, SWIGLU_CLAMP)
        return self.down_proj(gate * up)


class Expert(nn.Module):
    def __init__(self, config: ModelConfig):
        super().__init__()
        self.w1 = nn.Linear(config.d_model, config.expert_ffn, bias=False)
        self.w2 = nn.Linear(config.expert_ffn, config.d_model, bias=False)
        self.w3 = nn.Linear(config.d_model, config.expert_ffn, bias=False)

    def forward(self, hidden):
        gate = F.silu(self.w1(hidden)).clamp(max=SWIGLU_CLAMP)
        up   = self.w3(hidden).clamp(-SWIGLU_CLAMP, SWIGLU_CLAMP)
        return self.w2(gate * up)


class SparseMoE(nn.Module):

    def __init__(self, config: ModelConfig):
        super().__init__()
        self.top_k = config.top_k
        self.gate = nn.Linear(config.d_model, config.n_experts, bias=False)
        self.experts = nn.ModuleList(Expert(config) for _ in range(config.n_experts))

    def forward(self, hidden):
        original_shape = hidden.shape
        num_experts = len(self.experts)
        flat = hidden.reshape(-1, original_shape[-1])
        logits = self.gate(flat)
        top_values, selected = logits.topk(self.top_k, dim=-1)
        weights = top_values.softmax(-1).to(flat.dtype)
        out = torch.zeros_like(flat)
        for expert_idx, expert in enumerate(self.experts):
            token_idx, slot_idx = (selected == expert_idx).nonzero(as_tuple=True)
            if token_idx.numel():
                out.index_add_(0, token_idx, expert(flat[token_idx]) * weights[token_idx, slot_idx, None])
        counts = F.one_hot(selected, num_experts).sum((0, 1)).float()
        self.aux = num_experts * (counts / counts.sum() * logits.float().softmax(-1).mean(0)).sum()
        self.z_loss = torch.logsumexp(logits.float(), dim=-1).pow(2).mean()
        self.counts = counts.detach()
        return out.view(original_shape)


class SparseFGMoE(nn.Module):
    """Fine-grained MoE matching DeepSeek V4 nanowhale + Qwen3.5 HuggingFace source exactly.

    From DeepSeek V4 (huggingface/nanowhale/modeling_deepseek_v4.py):
      - sqrtsoftplus scoring BEFORE top-k selection (not after gathering)
      - Weights gathered from ORIGINAL logits (pre-scoring)
      - routed_scaling_factor scales final expert weights
      - Aux-loss-free bias routing with per-step updates
      - SwiGLU clamping on both gate and up (Expert class)

    From Qwen3.5 (transformers/models/qwen3_5_moe/modeling_qwen3_5_moe.py):
      - Shared expert with sigmoid gate: sigmoid(linear(h)) * shared_output
      - Renormalized top-k weights: w /= w.sum(keepdim=True)
      - Expert output cast to match shared expert dtype

    From ST-MoE / nanoMoE:
      - Router z-loss: logsumexp(logits).pow(2).mean()
      - Router computed in FP32"""

    def __init__(self, config: ModelConfig, hash_route: bool = False):
        super().__init__()
        self.top_k = config.top_k
        self.n_experts = config.n_experts
        self.bias_speed = config.bias_speed
        self.hash_route = hash_route
        self.gate_fn = config.gate_fn
        self.route_scale = config.route_scale
        self.experts = nn.ModuleList(Expert(config) for _ in range(config.n_experts))
        self.shared = Expert(config)
        self.shared_gate = nn.Linear(config.d_model, 1, bias=False)
        if hash_route:
            self.register_buffer("hash_proj", torch.randn(config.d_model, config.n_experts) * 0.01)
        else:
            self.gate = nn.Linear(config.d_model, config.n_experts, bias=False)
            self.register_buffer("bias", torch.zeros(config.n_experts))

    def _route(self, hidden, num_experts):
        if self.hash_route:
            scores = hidden @ self.hash_proj
            top_values, selected = scores.topk(self.top_k, dim=-1)
            weights = torch.ones_like(top_values) / self.top_k
            self.z_loss = torch.zeros((), device=hidden.device)
            self.seq_balance = torch.zeros((), device=hidden.device)
            return selected, weights
        logits = self.gate(hidden.float()).float()
        if self.gate_fn == "sqrt_softplus":
            scores = F.softplus(logits, threshold=50).sqrt()
        elif self.gate_fn == "sigmoid":
            scores = torch.sigmoid(logits)
        else:
            scores = logits.softmax(-1)
        routing = scores + self.bias
        _, selected = routing.topk(self.top_k, dim=-1)
        weights = logits.gather(-1, selected).softmax(-1) * self.route_scale
        weights = weights.to(hidden.dtype)
        self.z_loss = torch.logsumexp(logits.clamp(-50, 50), dim=-1).pow(2).mean()
        counts_soft = F.one_hot(selected.reshape(-1), num_experts).float().sum(0)
        probs_mean = scores.detach().mean(0)
        self.seq_balance = num_experts * (counts_soft / counts_soft.sum().clamp(min=1) * probs_mean).sum()
        return selected, weights

    def _dispatch_experts(self, hidden, selected, weights, out, num_experts):
        for expert_idx, expert in enumerate(self.experts):
            token_idx, slot_idx = (selected == expert_idx).nonzero(as_tuple=True)
            if token_idx.numel():
                contrib = (expert(hidden[token_idx]) * weights[token_idx, slot_idx, None]).to(out.dtype)
                out = out.index_add(0, token_idx, contrib)
        return out

    def _update_bias(self, selected, num_experts):
        counts = F.one_hot(selected.reshape(-1), num_experts).float().sum(0)
        if self.training and not self.hash_route:
            with torch.no_grad():
                load = counts / counts.sum().clamp(min=1)
                self.bias -= self.bias_speed * (load - 1.0 / num_experts)
        return counts

    def forward(self, hidden_input):
        original_shape = hidden_input.shape
        num_experts = len(self.experts)
        hidden = hidden_input.reshape(-1, original_shape[-1])
        selected, weights = self._route(hidden, num_experts)
        out = self.shared(hidden) * torch.sigmoid(self.shared_gate(hidden))
        out = self._dispatch_experts(hidden, selected, weights, out, num_experts)
        counts = self._update_bias(selected, num_experts)
        self.aux = torch.zeros((), device=hidden.device)
        self.counts = counts.detach()
        return out.view(original_shape)


def layer_is_full(config, layer_idx):
    return (layer_idx + 1) % config.hybrid == 0


class Block(nn.Module):
    def __init__(self, config: ModelConfig, layer_idx: int = 0):
        super().__init__()
        self.input_layernorm = RMSNorm(config.d_model, config.norm_eps)
        if not config.hybrid:
            self.self_attn = Attention(config)
        elif layer_is_full(config, layer_idx):
            self.self_attn = GatedAttention(config)
        else:
            self.linear_attn = GatedDeltaNet(config.d_model, config.lin_heads, config.lin_head_dim, config.conv_k, config.norm_eps)
        self.post_attention_layernorm = RMSNorm(config.d_model, config.norm_eps)
        if config.n_experts:
            use_hash = config.moe_style == "fg" and layer_idx < config.hash_layers
            self.block_sparse_moe = SparseFGMoE(config, hash_route=use_hash) if config.moe_style == "fg" else SparseMoE(config)
        else:
            self.mlp = MLP(config)

    def forward(self, hidden, cos, sin, cache=None):
        mixer = self.self_attn if hasattr(self, "self_attn") else self.linear_attn
        hidden = hidden + mixer(self.input_layernorm(hidden), cos, sin, cache)
        ffn = self.block_sparse_moe if hasattr(self, "block_sparse_moe") else self.mlp
        return hidden + ffn(self.post_attention_layernorm(hidden))


class YtteriaDragon(nn.Module):
    def __init__(self, config: ModelConfig):
        super().__init__()
        self.config = config
        self.embed_tokens = nn.Embedding(config.vocab_size, config.d_model)
        self.layers = nn.ModuleList(Block(config, layer_idx) for layer_idx in range(config.n_layers))
        self.norm = RMSNorm(config.d_model, config.norm_eps)
        self.lm_head = nn.Linear(config.d_model, config.vocab_size, bias=False)
        self.mtp = nn.ModuleList(Block(config, 0) for _ in range(config.mtp))
        if config.tie_embeddings:
            self.lm_head.weight = self.embed_tokens.weight
        rope_len = config.max_seq_len * 4 if config.attn_window else config.max_seq_len
        cos, sin = rope_cache(int(config.d_model // config.n_heads * (config.rope_frac if config.hybrid else 1.0)), rope_len, config.rope_theta)
        self.register_buffer("rope_cos", cos, persistent=False)
        self.register_buffer("rope_sin", sin, persistent=False)
        self.apply(self._init)
        if config.n_experts:
            for layer in list(self.layers) + list(self.mtp):
                if hasattr(layer, "block_sparse_moe"):
                    moe = layer.block_sparse_moe
                    for expert in moe.experts:
                        for weight in expert.parameters():
                            std = (0.1 / weight.shape[-1]) ** 0.5
                            nn.init.trunc_normal_(weight, mean=0.0, std=std, a=-2*std, b=2*std)
                    for weight in moe.shared.parameters():
                        std = (0.1 / weight.shape[-1]) ** 0.5
                        nn.init.trunc_normal_(weight, mean=0.0, std=std, a=-2*std, b=2*std)
                        weight.data += torch.randn_like(weight) * 1e-4

    @staticmethod
    def _init(module):
        if isinstance(module, (nn.Linear, nn.Embedding)):
            nn.init.normal_(module.weight, mean=0.0, std=0.02)

    def _run_transformer(self, token_ids, caches, pos):
        batch_size, seq_len = token_ids.shape
        cos, sin = self.rope_cos[pos:pos + seq_len], self.rope_sin[pos:pos + seq_len]
        if token_ids.device.type == "xpu" and token_ids.numel() > 1024:
            hidden = torch.cat([self.embed_tokens(chunk) for chunk in token_ids.split(max(1, 1024 // batch_size), dim=1)], dim=1)
        else:
            hidden = self.embed_tokens(token_ids)
        for layer_idx, layer in enumerate(self.layers):
            hidden = layer(hidden, cos, sin, None if caches is None else caches[layer_idx])
        return hidden, cos, sin

    def _compute_loss(self, hidden, targets, mtp_loss):
        if targets.numel() > LOSS_CHUNK:
            flat_hidden, flat_targets = hidden.reshape(-1, hidden.size(-1)), targets.reshape(-1)
            n_valid = (flat_targets != -100).sum().clamp(min=1)
            ce_fn = lambda chunk_h, chunk_t: F.cross_entropy(self.lm_head(chunk_h), chunk_t, ignore_index=-100, reduction="sum")
            loss = sum(torch.utils.checkpoint.checkpoint(ce_fn, chunk_h, chunk_t, use_reentrant=False)
                       for chunk_h, chunk_t in zip(flat_hidden.split(1024), flat_targets.split(1024))) / n_valid
            if self.config.n_experts and self.training:
                loss = loss + self.config.aux_coef * self.aux_loss() + self.config.z_loss_coef * self.z_loss() + self.config.seq_balance_coef * self.seq_balance_loss()
            if mtp_loss is not None:
                loss = loss + self.config.mtp_coef * mtp_loss
            return None, loss
        logits = self.lm_head(hidden)
        flat_logits, flat_targets = logits.view(-1, logits.size(-1)), targets.view(-1)
        if flat_logits.device.type == "xpu" and flat_targets.numel() > 1024:
            n_valid = (flat_targets != -100).sum().clamp(min=1)
            loss = sum(F.cross_entropy(chunk_l, chunk_t, ignore_index=-100, reduction="sum")
                       for chunk_l, chunk_t in zip(flat_logits.split(1024), flat_targets.split(1024))) / n_valid
        else:
            loss = F.cross_entropy(flat_logits, flat_targets, ignore_index=-100)
        if self.config.n_experts and self.training:
            loss = loss + self.config.aux_coef * self.aux_loss() + self.config.z_loss_coef * self.z_loss() + self.config.seq_balance_coef * self.seq_balance_loss()
        if mtp_loss is not None:
            loss = loss + self.config.mtp_coef * mtp_loss
        return logits, loss

    def forward(self, token_ids, targets=None, caches=None, pos=0):
        assert pos + token_ids.shape[1] <= self.config.max_seq_len, f"seq {pos + token_ids.shape[1]} > max_seq_len"
        hidden, cos, sin = self._run_transformer(token_ids, caches, pos)
        normed = self.norm(hidden)
        mtp_loss = self._mtp_loss(hidden, cos, sin, targets) if (self.config.mtp and self.training and targets is not None) else None
        if targets is not None:
            return self._compute_loss(normed, targets, mtp_loss)
        return self.lm_head(normed), None

    def _mtp_loss(self, hidden, cos, sin, targets):
        ce_fn = lambda chunk_h, chunk_t: F.cross_entropy(self.lm_head(chunk_h), chunk_t, ignore_index=-100, reduction="sum")
        losses = []
        for head_idx, block in enumerate(self.mtp):
            seq_keep = targets.size(1) - (head_idx + 1)
            if seq_keep <= 0:
                break
            head_hidden = self.norm(block(hidden, cos, sin, None))[:, :seq_keep].reshape(-1, hidden.size(-1))
            head_targets = targets[:, head_idx + 1:].reshape(-1)
            n_valid = (head_targets != -100).sum().clamp(min=1)
            losses.append(sum(torch.utils.checkpoint.checkpoint(ce_fn, chunk_h, chunk_t, use_reentrant=False)
                              for chunk_h, chunk_t in zip(head_hidden.split(1024), head_targets.split(1024))) / n_valid)
        return torch.stack(losses).mean()

    def aux_loss(self):
        """Mean MoE load-balancing loss over layers from the last forward (0 for dense)."""
        if not self.config.n_experts:
            return torch.zeros(())
        return torch.stack([layer.block_sparse_moe.aux for layer in self.layers]).mean()

    def z_loss(self):
        """Mean router z-loss (ST-MoE) over layers from the last forward (0 for dense)."""
        if not self.config.n_experts:
            return torch.zeros(())
        return torch.stack([layer.block_sparse_moe.z_loss for layer in self.layers]).mean()

    def seq_balance_loss(self):
        """Mean sequence-wise balance loss (DeepSeek V4) over layers (0 for dense/coarse)."""
        if not self.config.n_experts:
            return torch.zeros(())
        losses = []
        for layer in self.layers:
            if hasattr(layer.block_sparse_moe, "seq_balance"):
                losses.append(layer.block_sparse_moe.seq_balance)
        return torch.stack(losses).mean() if losses else torch.zeros(())

    def expert_counts(self):
        """(n_layers, n_experts) tokens routed per expert in the last forward, or None for dense."""
        if not self.config.n_experts:
            return None
        return torch.stack([layer.block_sparse_moe.counts for layer in self.layers])

    @torch.no_grad()
    def generate(self, ids, max_new=128, stop=(), temperature=0.0, caches=None):
        """Greedy (or sampled) decoding with a KV cache. ids: list[int]. Returns new token ids.
        With attn_window > 0, can generate beyond max_seq_len (auto-compacts KV cache)."""
        dev = self.embed_tokens.weight.device
        rope_max = self.config.max_seq_len * 4 if self.config.attn_window else self.config.max_seq_len
        ids = ids[-(self.config.max_seq_len - max_new):]
        if caches is None:
            caches = [{} for _ in self.layers]
        logits, _ = self(torch.tensor([ids], device=dev), caches=caches, pos=0)
        pos, out = len(ids), []
        for _ in range(max_new):
            last = logits[0, -1]
            nxt = int(last.argmax()) if temperature == 0 else int(torch.multinomial(torch.softmax(last / temperature, -1), 1))
            if nxt in stop:
                break
            out.append(nxt)
            if pos >= rope_max:
                break
            logits, _ = self(torch.tensor([[nxt]], device=dev), caches=caches, pos=pos)
            pos += 1
        return out

    @torch.no_grad()
    def auto_compact(self, caches, keep_last=None):
        """Compact KV caches during idle time. Call between user turns to free memory.

        For hybrid models:
        - GatedDeltaNet layers: already O(1), state unchanged.
        - GatedAttention layers: evict KV entries beyond the sliding window.

        Args:
            caches: list of per-layer cache dicts from generate().
            keep_last: tokens to keep. Defaults to config.attn_window or 256.
        Returns:
            compacted caches, number of tokens evicted.
        """
        window = keep_last or self.config.attn_window or 256
        evicted = 0
        for i, (layer, cache) in enumerate(zip(self.layers, caches)):
            if hasattr(layer, "self_attn") and "k" in cache:
                seq_len = cache["k"].shape[2]
                if seq_len > window:
                    evicted += seq_len - window
                    cache["k"] = cache["k"][:, :, -window:]
                    cache["v"] = cache["v"][:, :, -window:]
        return caches, evicted

    def cache_memory_bytes(self, caches):
        """Estimate memory used by inference caches (KV + GDN state) in bytes."""
        total = 0
        for cache in caches:
            for cache_key, cache_tensor in cache.items():
                if isinstance(cache_tensor, torch.Tensor):
                    total += cache_tensor.nelement() * cache_tensor.element_size()
        return total

    def num_params(self):
        return sum(parameter.numel() for parameter in self.parameters())

    def num_active_params(self):
        """Params used per token: MoE layers count top_k routed experts (+ shared expert for fg)."""
        if not self.config.n_experts:
            return self.num_params()
        moe = self.layers[0].block_sparse_moe
        per_expert = sum(parameter.numel() for parameter in moe.experts[0].parameters())
        inactive = self.config.n_layers * (self.config.n_experts - self.config.top_k) * per_expert
        return self.num_params() - inactive


PRESETS = {
    "10M": ModelConfig(vocab_size=32768, max_seq_len=1024, d_model=256, n_layers=4,
                       n_heads=4, n_kv_heads=2, ffn_hidden=768, rope_theta=100000.0),
    "30M": ModelConfig(vocab_size=32768, max_seq_len=2048, d_model=384, n_layers=10,
                       n_heads=6, n_kv_heads=2, ffn_hidden=1024, rope_theta=100000.0),
    "100M": ModelConfig(vocab_size=32768, max_seq_len=2048, d_model=640, n_layers=18,
                        n_heads=10, n_kv_heads=2, ffn_hidden=1792, rope_theta=100000.0),
}


PRESETS["30M-moe8"] = ModelConfig(vocab_size=32768, max_seq_len=2048, d_model=384, n_layers=10,
                                  n_heads=6, n_kv_heads=2, ffn_hidden=1024, rope_theta=100000.0,
                                  n_experts=8, top_k=2, expert_ffn=512)


PRESETS["30M-fgmoe"] = ModelConfig(vocab_size=32768, max_seq_len=2048, d_model=384, n_layers=10,
                                   n_heads=6, n_kv_heads=2, ffn_hidden=1024, rope_theta=100000.0,
                                   n_experts=32, top_k=2, expert_ffn=320, moe_style="fg")
PRESETS["30M-hybrid-fgmoe"] = ModelConfig(vocab_size=32768, max_seq_len=2048, d_model=384, n_layers=10,
                                           n_heads=6, n_kv_heads=2, ffn_hidden=1024, rope_theta=100000.0,
                                           hybrid=4,
                                           n_experts=32, top_k=2, expert_ffn=320, moe_style="fg")
PRESETS["30M-hybrid-fgmoe-mtp"] = ModelConfig(**{**PRESETS["30M-hybrid-fgmoe"].__dict__, "mtp": 1})
PRESETS["30M-moe8-mtp"] = ModelConfig(**{**PRESETS["30M-moe8"].__dict__, "mtp": 1})
PRESETS["30M-mtp"] = ModelConfig(**{**PRESETS["30M"].__dict__, "mtp": 1})
PRESETS["30M-hybrid"] = ModelConfig(vocab_size=32768, max_seq_len=2048, d_model=384, n_layers=10,
                                    n_heads=6, n_kv_heads=2, ffn_hidden=768, rope_theta=100000.0, hybrid=4)

PRESETS["300M"] = ModelConfig(vocab_size=32768, max_seq_len=2048, d_model=1024, n_layers=24,
                              n_heads=16, n_kv_heads=4, ffn_hidden=2816, rope_theta=100000.0)
PRESETS["500M"] = ModelConfig(vocab_size=32768, max_seq_len=2048, d_model=1280, n_layers=26,
                              n_heads=20, n_kv_heads=4, ffn_hidden=3584, rope_theta=100000.0)



PRESETS["50M-tinda360"] = ModelConfig(
    vocab_size=8192, max_seq_len=1024, d_model=192, n_layers=8,
    n_heads=4, n_kv_heads=2, ffn_hidden=512, rope_theta=10000.0,
    n_experts=32, top_k=1, expert_ffn=192, moe_style="fg",
    hash_layers=2, gate_fn="sqrt_softplus",
    hybrid=4, lin_heads=4, lin_head_dim=48, conv_k=4, rope_frac=0.25,
    mtp=1, attn_window=512,
)


PRESETS["5M-tinda360"] = ModelConfig(
    vocab_size=8192, max_seq_len=1024, d_model=128, n_layers=6,
    n_heads=4, n_kv_heads=2, ffn_hidden=344, rope_theta=10000.0,
    n_experts=16, top_k=1, expert_ffn=96, moe_style="fg",
    hash_layers=2, gate_fn="sqrt_softplus",
    hybrid=4, lin_heads=4, lin_head_dim=32, conv_k=4, rope_frac=0.25,
    mtp=1, attn_window=512,
)


def param_groups(model, weight_decay):
    """AdamW groups (A11): decay only matrices; RMSNorm gains (ndim < 2) and the (tied)
    embedding get weight_decay 0. Order is fixed: decay group first, then no-decay."""
    decay, no_decay = [], []
    for name, parameter in model.named_parameters():
        if not parameter.requires_grad:
            continue
        (no_decay if parameter.ndim < 2 or "embed_tokens" in name else decay).append(parameter)
    return [{"params": decay, "weight_decay": weight_decay}, {"params": no_decay, "weight_decay": 0.0}]


def muon_groups(model, weight_decay, adamw_lr_scale=0.1):
    """Muon optimizer split (Qwen3.8-Flash-Next / Keller Jordan 2024):
    - muon: 2-D weight matrices in attn, MoE experts, MLP (orthogonal update via Newton-Schulz).
    - adamw: everything else (embeddings, norms, router gate, MoE bias, 1-D params).
    Returns (muon_params, adamw_groups). adamw_lr_scale is applied to the adamw group LR at call site.
    """



    _MUON_SKIP = {"embed_tokens", "gate", "bias", "norm", "experts", "shared", "shared_gate", "hash_proj"}
    muon, adamw_decay, adamw_nodecay = [], [], []
    for name, parameter in model.named_parameters():
        if not parameter.requires_grad:
            continue
        skip = parameter.ndim < 2 or any(key in name for key in _MUON_SKIP)
        if skip:
            if parameter.ndim >= 2 and "embed_tokens" not in name and "norm" not in name:
                adamw_decay.append(parameter)
            else:
                adamw_nodecay.append(parameter)
        else:
            muon.append(parameter)
    return muon, [
        {"params": adamw_decay, "weight_decay": weight_decay, "_lr_scale": adamw_lr_scale},
        {"params": adamw_nodecay, "weight_decay": 0.0, "_lr_scale": adamw_lr_scale},
    ]


class MuonOptimizer:
    """Muon optimizer (Keller Jordan 2024, updated to match github.com/KellerJordan/Muon).
    Nesterov momentum + Newton-Schulz orthogonalization on 2-D weight matrices.
    Paired with AdamW for scalar/embedding params.

    Key differences from naive implementation:
    - Quintic NS coefficients (3.4445, -4.7750, 2.0315) for faster convergence
    - NS computed in bfloat16 on GPU for speed
    - Aspect ratio scaling for non-square matrices
    - Multiplicative weight decay before update
    """

    NS_STEPS = 5
    NS_COEFF_A, NS_COEFF_B, NS_COEFF_C = 3.4445, -4.7750, 2.0315

    def __init__(self, muon_params, adamw_optimizer, lr=0.02, momentum=0.95, weight_decay=0.0):
        self.params = list(muon_params)
        self.adamw = adamw_optimizer
        self.lr = lr
        self.momentum = momentum
        self.weight_decay = weight_decay
        self.buf = [torch.zeros_like(init_param) for init_param in self.params]

    @staticmethod
    def _ns(gradient):
        norm_grad = gradient.bfloat16() if gradient.is_cuda else gradient.float()
        norm_grad = norm_grad / (norm_grad.norm() + 1e-7)
        coeff_a = MuonOptimizer.NS_COEFF_A
        coeff_b = MuonOptimizer.NS_COEFF_B
        coeff_c = MuonOptimizer.NS_COEFF_C
        for _ in range(MuonOptimizer.NS_STEPS):
            moment = norm_grad @ norm_grad.mT
            norm_grad = coeff_a * norm_grad + (coeff_b * moment + coeff_c * moment @ moment) @ norm_grad
        return norm_grad

    @torch.no_grad()
    def step(self, zero_grad=True):
        for weight_param, momentum_buf in zip(self.params, self.buf):
            if weight_param.grad is None:
                continue
            grad = weight_param.grad.float()
            momentum_buf.mul_(self.momentum).add_(grad)
            update = momentum_buf + self.momentum * (momentum_buf - grad) if self.momentum else momentum_buf
            if update.ndim == 2:
                update = self._ns(update)
                update = update * max(1, update.shape[-2] / update.shape[-1]) ** 0.5
                update = update.to(weight_param.dtype)
            else:
                update = update.to(weight_param.dtype)
            if self.weight_decay > 0:
                weight_param.mul_(1 - self.lr * self.weight_decay)
            weight_param.add_(update, alpha=-self.lr)
        self.adamw.step()
        if zero_grad:
            for param in self.params:
                param.grad = None
            self.adamw.zero_grad(set_to_none=True)

    def zero_grad(self, set_to_none=True):
        for tracked_param in self.params:
            if set_to_none:
                tracked_param.grad = None
            elif tracked_param.grad is not None:
                tracked_param.grad.zero_()
        self.adamw.zero_grad(set_to_none=set_to_none)

    def state_dict(self):
        return {"buf": [momentum_tensor.cpu() for momentum_tensor in self.buf], "lr": self.lr, "momentum": self.momentum,
                "adamw": self.adamw.state_dict()}

    def load_state_dict(self, sd):
        for momentum_buf, saved in zip(self.buf, sd["buf"]):
            momentum_buf.copy_(saved.to(momentum_buf.device))
        self.lr = sd["lr"]
        self.momentum = sd["momentum"]
        self.adamw.load_state_dict(sd["adamw"])


def load_opt_state(opt, sd, model):
    """Load an optimizer state_dict saved with a single model.parameters() group (checkpoints
    before A11) into the param-group optimizer; newer state dicts load as they are."""
    if len(sd["param_groups"]) == len(opt.param_groups):
        opt.load_state_dict(sd)
        return
    assert len(sd["param_groups"]) == 1, "unknown optimizer state layout"
    old_pos = {id(old_param): slot for slot, old_param in enumerate(model.parameters())}
    old_idx = sd["param_groups"][0]["params"]
    new_groups, new_state, counter = [], {}, 0
    for group in opt.param_groups:
        param_ids = []
        for opt_param in group["params"]:
            old_slot = old_idx[old_pos[id(opt_param)]]
            if old_slot in sd["state"]:
                new_state[counter] = sd["state"][old_slot]
            param_ids.append(counter)
            counter += 1
        new_groups.append({**sd["param_groups"][0], "weight_decay": group["weight_decay"], "params": param_ids})
    opt.load_state_dict({"state": new_state, "param_groups": new_groups})
