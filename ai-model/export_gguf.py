import argparse
import json
import os
import numpy as np

import torch

from model import ModelConfig, YtteriaDragon


def parse_args():
    parser = argparse.ArgumentParser(description="Export YtteriaDragon to GGUF")
    parser.add_argument("--checkpoint", required=True)
    parser.add_argument("--tokenizer", default="tokenizer.json")
    parser.add_argument("--output", default="tinda360.gguf")
    parser.add_argument("--quantize", default=None, choices=[None, "f16", "q8_0", "q4_k_m", "q4_0"])
    parser.add_argument("--description", default="YtteriaDragon Tinda360 intent classifier")
    return parser.parse_args()


def load_checkpoint(path):
    state = torch.load(path, map_location="cpu", weights_only=False)
    config = ModelConfig(**state["config"])
    model = YtteriaDragon(config)
    model.load_state_dict(state["model"])
    model.eval()
    return model, config, state


def load_tokenizer_vocab(path):
    with open(path) as file_handle:
        tok_data = json.load(file_handle)
    vocab = tok_data.get("model", {}).get("vocab", {})
    tokens = [""] * len(vocab)
    for token_str, token_id in vocab.items():
        if token_id < len(tokens):
            tokens[token_id] = token_str
    for added in tok_data.get("added_tokens", []):
        tid = added["id"]
        if tid < len(tokens):
            tokens[tid] = added["content"]
    return tokens


def get_arch_name(config):
    if config.hybrid:
        return "qwen3_5"
    return "llama"


def _attention_name_map_for_layer(config, layer_idx, pytorch_prefix, gguf_prefix):
    mapping = {}
    if config.hybrid:
        from model import layer_is_full
        if layer_is_full(config, layer_idx):
            mapping[f"{pytorch_prefix}.self_attn.q_proj.weight"] = f"{gguf_prefix}.attn_q.weight"
            mapping[f"{pytorch_prefix}.self_attn.k_proj.weight"] = f"{gguf_prefix}.attn_k.weight"
            mapping[f"{pytorch_prefix}.self_attn.v_proj.weight"] = f"{gguf_prefix}.attn_v.weight"
            mapping[f"{pytorch_prefix}.self_attn.o_proj.weight"] = f"{gguf_prefix}.attn_output.weight"
            mapping[f"{pytorch_prefix}.self_attn.q_norm.weight"] = f"{gguf_prefix}.attn_q_norm.weight"
            mapping[f"{pytorch_prefix}.self_attn.k_norm.weight"] = f"{gguf_prefix}.attn_k_norm.weight"
        else:
            mapping[f"{pytorch_prefix}.linear_attn.in_proj_qkv.weight"] = f"{gguf_prefix}.ssm_in.weight"
            mapping[f"{pytorch_prefix}.linear_attn.in_proj_z.weight"]   = f"{gguf_prefix}.ssm_z.weight"
            mapping[f"{pytorch_prefix}.linear_attn.in_proj_b.weight"]   = f"{gguf_prefix}.ssm_b.weight"
            mapping[f"{pytorch_prefix}.linear_attn.in_proj_a.weight"]   = f"{gguf_prefix}.ssm_a.weight"
            mapping[f"{pytorch_prefix}.linear_attn.conv1d.weight"]      = f"{gguf_prefix}.ssm_conv1d.weight"
            mapping[f"{pytorch_prefix}.linear_attn.dt_bias"]            = f"{gguf_prefix}.ssm_dt.bias"
            mapping[f"{pytorch_prefix}.linear_attn.A_log"]              = f"{gguf_prefix}.ssm_a_log"
            mapping[f"{pytorch_prefix}.linear_attn.norm.weight"]        = f"{gguf_prefix}.ssm_norm.weight"
            mapping[f"{pytorch_prefix}.linear_attn.out_proj.weight"]    = f"{gguf_prefix}.ssm_out.weight"
    else:
        mapping[f"{pytorch_prefix}.self_attn.q_proj.weight"] = f"{gguf_prefix}.attn_q.weight"
        mapping[f"{pytorch_prefix}.self_attn.k_proj.weight"] = f"{gguf_prefix}.attn_k.weight"
        mapping[f"{pytorch_prefix}.self_attn.v_proj.weight"] = f"{gguf_prefix}.attn_v.weight"
        mapping[f"{pytorch_prefix}.self_attn.o_proj.weight"] = f"{gguf_prefix}.attn_output.weight"
    return mapping


def _moe_name_map_for_layer(config, layer_idx, pytorch_prefix, gguf_prefix):
    mapping = {}
    if not config.n_experts:
        mapping[f"{pytorch_prefix}.mlp.gate_proj.weight"] = f"{gguf_prefix}.ffn_gate.weight"
        mapping[f"{pytorch_prefix}.mlp.down_proj.weight"] = f"{gguf_prefix}.ffn_down.weight"
        mapping[f"{pytorch_prefix}.mlp.up_proj.weight"]   = f"{gguf_prefix}.ffn_up.weight"
        return mapping

    if config.moe_style == "fg":
        is_hash = config.hash_layers and layer_idx < config.hash_layers
        if is_hash:
            mapping[f"{pytorch_prefix}.block_sparse_moe.hash_proj"] = f"{gguf_prefix}.ffn_hash_proj"
        else:
            mapping[f"{pytorch_prefix}.block_sparse_moe.gate.weight"] = f"{gguf_prefix}.ffn_gate_inp.weight"
            mapping[f"{pytorch_prefix}.block_sparse_moe.bias"]        = f"{gguf_prefix}.ffn_gate_inp.bias"
        mapping[f"{pytorch_prefix}.block_sparse_moe.shared.w1.weight"]   = f"{gguf_prefix}.ffn_gate_shexp.weight"
        mapping[f"{pytorch_prefix}.block_sparse_moe.shared.w2.weight"]   = f"{gguf_prefix}.ffn_down_shexp.weight"
        mapping[f"{pytorch_prefix}.block_sparse_moe.shared.w3.weight"]   = f"{gguf_prefix}.ffn_up_shexp.weight"
        mapping[f"{pytorch_prefix}.block_sparse_moe.shared_gate.weight"] = f"{gguf_prefix}.ffn_gate_shexp_scale.weight"
        for expert_idx in range(config.n_experts):
            mapping[f"{pytorch_prefix}.block_sparse_moe.experts.{expert_idx}.w1.weight"] = f"{gguf_prefix}.ffn_gate_exps.{expert_idx}.weight"
            mapping[f"{pytorch_prefix}.block_sparse_moe.experts.{expert_idx}.w2.weight"] = f"{gguf_prefix}.ffn_down_exps.{expert_idx}.weight"
            mapping[f"{pytorch_prefix}.block_sparse_moe.experts.{expert_idx}.w3.weight"] = f"{gguf_prefix}.ffn_up_exps.{expert_idx}.weight"
    else:
        mapping[f"{pytorch_prefix}.block_sparse_moe.gate.weight"] = f"{gguf_prefix}.ffn_gate_inp.weight"
        for expert_idx in range(config.n_experts):
            mapping[f"{pytorch_prefix}.block_sparse_moe.experts.{expert_idx}.w1.weight"] = f"{gguf_prefix}.ffn_gate_exps.{expert_idx}.weight"
            mapping[f"{pytorch_prefix}.block_sparse_moe.experts.{expert_idx}.w2.weight"] = f"{gguf_prefix}.ffn_down_exps.{expert_idx}.weight"
            mapping[f"{pytorch_prefix}.block_sparse_moe.experts.{expert_idx}.w3.weight"] = f"{gguf_prefix}.ffn_up_exps.{expert_idx}.weight"
    return mapping


def weight_name_map(config):
    mapping = {}
    mapping["embed_tokens.weight"] = "token_embd.weight"
    mapping["norm.weight"] = "output_norm.weight"
    if not config.tie_embeddings:
        mapping["lm_head.weight"] = "output.weight"

    for layer_idx in range(config.n_layers):
        pytorch_prefix = f"layers.{layer_idx}"
        gguf_prefix    = f"blk.{layer_idx}"
        mapping[f"{pytorch_prefix}.input_layernorm.weight"]       = f"{gguf_prefix}.attn_norm.weight"
        mapping[f"{pytorch_prefix}.post_attention_layernorm.weight"] = f"{gguf_prefix}.ffn_norm.weight"
        mapping.update(_attention_name_map_for_layer(config, layer_idx, pytorch_prefix, gguf_prefix))
        mapping.update(_moe_name_map_for_layer(config, layer_idx, pytorch_prefix, gguf_prefix))

    return mapping


def _write_gguf_metadata(writer, config, description):
    writer.add_name(description)
    writer.add_context_length(config.max_seq_len)
    writer.add_embedding_length(config.d_model)
    writer.add_block_count(config.n_layers)
    writer.add_head_count(config.n_heads)
    writer.add_head_count_kv(config.n_kv_heads)
    writer.add_feed_forward_length(config.ffn_hidden)
    writer.add_rope_freq_base(config.rope_theta)
    writer.add_layer_norm_rms_eps(config.norm_eps)
    writer.add_vocab_size(config.vocab_size)
    if config.n_experts:
        writer.add_expert_count(config.n_experts)
        writer.add_expert_used_count(config.top_k)


def _write_gguf_tokenizer(writer, tokenizer_path):
    if not os.path.exists(tokenizer_path):
        return
    tokens = load_tokenizer_vocab(tokenizer_path)
    token_bytes = [token_str.encode("utf-8", errors="replace") for token_str in tokens]
    scores = [0.0] * len(tokens)
    token_types = [0] * len(tokens)
    special_names = {"[PAD]", "[BOS]", "[EOS]", "[UNK]"}
    for token_idx, token_str in enumerate(tokens):
        if token_str in special_names:
            token_types[token_idx] = 3
    writer.add_tokenizer_model("bpe")
    writer.add_token_list(token_bytes)
    writer.add_token_scores(scores)
    writer.add_token_types(token_types)
    bos_id = tokens.index("[BOS]") if "[BOS]" in tokens else 1
    eos_id = tokens.index("[EOS]") if "[EOS]" in tokens else 2
    pad_id = tokens.index("[PAD]") if "[PAD]" in tokens else 0
    writer.add_bos_token_id(bos_id)
    writer.add_eos_token_id(eos_id)
    writer.add_pad_token_id(pad_id)


def _write_gguf_tensors(writer, model, config, quantize):
    import gguf as gguf_module
    name_map = weight_name_map(config)
    skipped = []

    for pt_name, tensor in model.state_dict().items():
        if pt_name.startswith("mtp."):
            skipped.append(pt_name)
            continue
        if any(rope_key in pt_name for rope_key in ["rope_cos", "rope_sin"]):
            skipped.append(pt_name)
            continue
        gguf_name = name_map.get(pt_name)
        if gguf_name is None:
            skipped.append(pt_name)
            continue
        data = tensor.detach().float().numpy()
        if quantize == "f16":
            data = data.astype(np.float16)
            writer.add_tensor(gguf_name, data, raw_dtype=gguf_module.GGMLQuantizationType.F16)
        else:
            writer.add_tensor(gguf_name, data)

    if skipped:
        print(f"  Skipped {len(skipped)} tensors (MTP heads, buffers):")
        for skipped_name in skipped[:10]:
            print(f"    {skipped_name}")
        if len(skipped) > 10:
            print(f"    ... and {len(skipped) - 10} more")


def export_gguf(model, config, tokenizer_path, output_path, quantize=None, description=""):
    try:
        import gguf
    except ImportError:
        print("ERROR: `gguf` package not installed. Install with: pip install gguf")
        fallback = output_path.replace(".gguf", "_state_dict.pt")
        torch.save({"model": model.state_dict(), "config": config.__dict__}, fallback)
        print(f"  Saved PyTorch state dict instead: {fallback}")
        return

    arch = get_arch_name(config)
    writer = gguf.GGUFWriter(output_path, arch)
    _write_gguf_metadata(writer, config, description)
    _write_gguf_tokenizer(writer, tokenizer_path)
    _write_gguf_tensors(writer, model, config, quantize)

    writer.write_header_to_file()
    writer.write_kv_data_to_file()
    writer.write_tensors_to_file()
    writer.close()

    size_mb = os.path.getsize(output_path) / 1024 / 1024
    print(f"  GGUF written: {output_path} ({size_mb:.1f} MB)")
    print(f"  Quantization: {quantize or 'f32'}")
    print(f"  Architecture: {arch}")

    if quantize in ("q4_k_m", "q4_0"):
        print(f"\n  NOTE: {quantize} requires llama.cpp's quantize tool.")
        print(f"    Run: llama-quantize {output_path} {output_path.replace('.gguf', f'-{quantize}.gguf')} {quantize}")


def main():
    args = parse_args()
    print(f"Loading checkpoint: {args.checkpoint}")
    model, config, _ = load_checkpoint(args.checkpoint)
    print(f"  Config: d={config.d_model}, layers={config.n_layers}, experts={config.n_experts}")
    print(f"  Params: {model.num_params():,} total")
    export_gguf(model, config, args.tokenizer, args.output, args.quantize, args.description)


if __name__ == "__main__":
    main()
