import torch
import torch.nn as nn
import torch.nn.functional as F


def l2norm(tensor, eps=1e-6):
    return tensor * torch.rsqrt((tensor * tensor).sum(-1, keepdim=True) + eps)


def chunk_gated_delta_rule(query, key, value, log_decay, beta, chunk=64, state=None):
    out_dtype = query.dtype
    batch_size, seq_len, n_heads, key_dim = key.shape
    val_dim = value.shape[-1]
    query, key, value, beta, log_decay = [
        tensor.transpose(1, 2).float().contiguous()
        for tensor in (query, key, value, beta, log_decay)
    ]
    query, key = l2norm(query), l2norm(key)
    query = query * key_dim ** -0.5
    pad = (chunk - seq_len % chunk) % chunk
    query, key, value = (F.pad(seq_tensor, (0, 0, 0, pad)) for seq_tensor in (query, key, value))
    beta, log_decay = (F.pad(head_tensor, (0, pad)) for head_tensor in (beta, log_decay))
    n_chunks = (seq_len + pad) // chunk
    gated_value = value * beta.unsqueeze(-1)
    gated_key   = key   * beta.unsqueeze(-1)
    query, key, gated_key, gated_value = [
        tensor.reshape(batch_size, n_heads, n_chunks, chunk, tensor.shape[-1])
        for tensor in (query, key, gated_key, gated_value)
    ]
    log_decay = log_decay.reshape(batch_size, n_heads, n_chunks, chunk)
    upper_mask = torch.ones(chunk, chunk, dtype=torch.bool, device=query.device).triu(1)
    cum_decay = log_decay.cumsum(3)
    pair_weights = (cum_decay.unsqueeze(4) - cum_decay.unsqueeze(3)).masked_fill(upper_mask, float("-inf")).exp()
    lower_tri = (gated_key @ key.transpose(-1, -2)) * pair_weights
    intra_attn = (query @ key.transpose(-1, -2)) * pair_weights
    gated_key_cum = gated_key * cum_decay.exp().unsqueeze(-1)
    new_value = torch.linalg.solve_triangular(lower_tri, gated_value, upper=False, unitriangular=True)
    key_cum   = torch.linalg.solve_triangular(lower_tri, gated_key_cum, upper=False, unitriangular=True)
    state_matrix = torch.zeros(batch_size, n_heads, key_dim, val_dim, device=query.device) if state is None else state.float()
    outs = []
    query = query * cum_decay.exp().unsqueeze(-1)
    key   = key   * (cum_decay[..., -1:] - cum_decay).exp().unsqueeze(-1)
    chunk_decay = cum_decay[..., -1].exp()[..., None, None]
    for chunk_idx in range(n_chunks):
        corrected_value = new_value[:, :, chunk_idx] - key_cum[:, :, chunk_idx] @ state_matrix
        outs.append(query[:, :, chunk_idx] @ state_matrix + intra_attn[:, :, chunk_idx] @ corrected_value)
        state_matrix = state_matrix * chunk_decay[:, :, chunk_idx] + key[:, :, chunk_idx].transpose(-1, -2) @ corrected_value
    out = torch.stack(outs, 2).reshape(batch_size, n_heads, n_chunks * chunk, val_dim)[:, :, :seq_len]
    return out.transpose(1, 2).to(out_dtype), state_matrix


class RMSNormGated(nn.Module):
    def __init__(self, dim, eps):
        super().__init__()
        self.eps = eps
        self.weight = nn.Parameter(torch.ones(dim))

    def forward(self, hidden, gate):
        normed = hidden * torch.rsqrt(hidden.pow(2).mean(-1, keepdim=True) + self.eps)
        return self.weight * normed * F.silu(gate)


class GatedDeltaNet(nn.Module):

    def __init__(self, d_model, n_heads, head_dim, conv_k, eps):
        super().__init__()
        self.H, self.hd, self.ck = n_heads, head_dim, conv_k
        dim = n_heads * head_dim
        self.conv_dim = 3 * dim
        self.in_proj_qkv = nn.Linear(d_model, self.conv_dim, bias=False)
        self.in_proj_z = nn.Linear(d_model, dim, bias=False)
        self.in_proj_b = nn.Linear(d_model, n_heads, bias=False)
        self.in_proj_a = nn.Linear(d_model, n_heads, bias=False)
        self.conv1d = nn.Conv1d(self.conv_dim, self.conv_dim, conv_k, groups=self.conv_dim, bias=False)
        self.dt_bias = nn.Parameter(torch.ones(n_heads))
        self.A_log = nn.Parameter(torch.log(torch.empty(n_heads).uniform_(0.01, 16)))
        self.norm = RMSNormGated(head_dim, eps)
        self.out_proj = nn.Linear(dim, d_model, bias=False)

    def forward(self, hidden, cos=None, sin=None, cache=None):
        batch_size, seq_len, _ = hidden.shape
        mixed = self.in_proj_qkv(hidden).transpose(1, 2)
        prev_conv = cache.get("conv") if cache is not None else None
        if prev_conv is None:
            prev_conv = mixed.new_zeros(batch_size, self.conv_dim, self.ck - 1)
        full_conv = torch.cat([prev_conv, mixed], 2)
        if cache is not None:
            cache["conv"] = full_conv[:, :, -(self.ck - 1):]
        mixed = F.silu(self.conv1d(full_conv)).transpose(1, 2)
        dim = self.H * self.hd
        query, key, value = (split_t.reshape(batch_size, seq_len, self.H, self.hd) for split_t in mixed.split(dim, -1))
        beta = self.in_proj_b(hidden).sigmoid()
        log_decay = -self.A_log.float().exp() * F.softplus(self.in_proj_a(hidden).float() + self.dt_bias)
        attended, state_out = chunk_gated_delta_rule(
            query, key, value, log_decay, beta,
            state=None if cache is None else cache.get("S"),
        )
        if cache is not None:
            cache["S"] = state_out
        out_gate = self.in_proj_z(hidden).reshape(batch_size, seq_len, self.H, self.hd)
        return self.out_proj(self.norm(attended, out_gate).reshape(batch_size, seq_len, dim))
