#include "ytteria.h"
#include <cmath>
#include <cstring>
#include <cstdio>
#include <cstdlib>
#include <vector>
#include <string>
#include <unordered_map>
#include <algorithm>
#include <cassert>
#include <climits>
#include <mutex>

#ifdef __ANDROID__
#include <android/log.h>
#define YLOG(...) __android_log_print(ANDROID_LOG_INFO, "ytteria", __VA_ARGS__)
#else
#define YLOG(...) do { fprintf(stderr, "[ytteria] "); fprintf(stderr, __VA_ARGS__); } while(0)
#endif

static constexpr int   D_MODEL            = 128;
static constexpr int   N_LAYERS           = 6;
static constexpr int   N_HEADS            = 4;
static constexpr int   N_KV_HEADS         = 2;
static constexpr int   HEAD_DIM           = 32;
static constexpr int   N_EXPERTS          = 16;
static constexpr int   EXPERT_HIDDEN      = 96;
static constexpr int   GDN_HEADS          = 4;
static constexpr int   GDN_HEAD_DIM       = 32;
static constexpr int   CONV_KERNEL        = 4;
static constexpr int   HASH_LAYERS        = 2;
static constexpr int   FULL_ATTN_LAYER    = 3;
static constexpr float NORM_EPS           = 1e-6f;
static constexpr int   ROPE_MAX           = 4096;
static constexpr int   ROPE_DIMS          = HEAD_DIM / 4;
static constexpr int   ROPE_HALF          = ROPE_DIMS / 2;
static constexpr int   ATTN_WINDOW        = 1024;
static constexpr float SWIGLU_CLAMP       = 10.0f;

static inline bool layer_is_gdn(int i) { return i != FULL_ATTN_LAYER; }

static float f16_to_f32(uint16_t h) {
    uint32_t sign     = (h >> 15) & 1u;
    uint32_t exponent = (h >> 10) & 0x1fu;
    uint32_t mantissa = h & 0x3ffu;
    if (exponent == 0x1f) {
        uint32_t v = (sign << 31) | 0x7f800000u | (mantissa << 13);
        float f; std::memcpy(&f, &v, 4); return f;
    }
    if (exponent == 0) {
        float f = std::ldexp((float)mantissa, -24);
        return sign ? -f : f;
    }
    uint32_t v = (sign << 31) | ((exponent + 112) << 23) | (mantissa << 13);
    float f; std::memcpy(&f, &v, 4); return f;
}

enum GgufType : uint32_t {
    GGUF_UINT8=0, GGUF_INT8=1, GGUF_UINT16=2, GGUF_INT16=3,
    GGUF_UINT32=4, GGUF_INT32=5, GGUF_FLOAT32=6, GGUF_BOOL=7,
    GGUF_STRING=8, GGUF_ARRAY=9, GGUF_UINT64=10, GGUF_INT64=11, GGUF_FLOAT64=12
};
enum GgmlType : uint32_t { GGML_F32=0, GGML_F16=1 };

struct TensorInfo {
    std::string name;
    std::vector<uint64_t> shape;
    uint32_t dtype;
    uint64_t offset;
};

struct GgufContext {
    FILE* fp = nullptr;
    uint64_t data_offset = 0;
    int vocab_size = 0;
    std::unordered_map<std::string, TensorInfo> tensors;
    ~GgufContext() { if (fp) fclose(fp); }
};

static std::string read_string(FILE* fp) {
    uint64_t len; fread(&len, 8, 1, fp);
    if (len == 0) return "";
    std::string s(len, '\0');
    fread(&s[0], 1, len, fp);
    return s;
}

static void skip_kv_value(FILE* fp, uint32_t type) {
    switch (type) {
        case GGUF_UINT8: case GGUF_INT8: case GGUF_BOOL: fseek(fp, 1, SEEK_CUR); break;
        case GGUF_UINT16: case GGUF_INT16: fseek(fp, 2, SEEK_CUR); break;
        case GGUF_UINT32: case GGUF_INT32: case GGUF_FLOAT32: fseek(fp, 4, SEEK_CUR); break;
        case GGUF_UINT64: case GGUF_INT64: case GGUF_FLOAT64: fseek(fp, 8, SEEK_CUR); break;
        case GGUF_STRING: { uint64_t l; fread(&l, 8, 1, fp); fseek(fp, (long)l, SEEK_CUR); } break;
        case GGUF_ARRAY: {
            uint32_t at; fread(&at, 4, 1, fp);
            uint64_t ac; fread(&ac, 8, 1, fp);
            for (uint64_t i = 0; i < ac; i++) skip_kv_value(fp, at);
        } break;
        default: break;
    }
}

static bool gguf_open(GgufContext& ctx, const char* path) {
    ctx.fp = fopen(path, "rb");
    if (!ctx.fp) { YLOG("Cannot open: %s\n", path); return false; }
    uint32_t magic, version;
    fread(&magic, 4, 1, ctx.fp);
    if (magic != 0x46554747u) { YLOG("Not a GGUF file: %s\n", path); return false; }
    fread(&version, 4, 1, ctx.fp);
    if (version < 2) { YLOG("GGUF version %u not supported\n", version); return false; }
    uint64_t n_tensors, n_kv;
    fread(&n_tensors, 8, 1, ctx.fp);
    fread(&n_kv, 8, 1, ctx.fp);
    for (uint64_t i = 0; i < n_kv; i++) {
        const std::string key = read_string(ctx.fp);
        uint32_t vtype; fread(&vtype, 4, 1, ctx.fp);
        if (key.size() >= 10 && key.substr(key.size() - 10) == "vocab_size" && vtype == GGUF_UINT32) {
            uint32_t vsz; fread(&vsz, 4, 1, ctx.fp);
            ctx.vocab_size = static_cast<int>(vsz);
        } else {
            skip_kv_value(ctx.fp, vtype);
        }
    }
    for (uint64_t i = 0; i < n_tensors; i++) {
        TensorInfo ti;
        ti.name = read_string(ctx.fp);
        uint32_t ndim; fread(&ndim, 4, 1, ctx.fp);
        ti.shape.resize(ndim);
        for (uint32_t d = 0; d < ndim; d++) { uint64_t dim; fread(&dim, 8, 1, ctx.fp); ti.shape[d] = dim; }
        fread(&ti.dtype, 4, 1, ctx.fp);
        fread(&ti.offset, 8, 1, ctx.fp);
        ctx.tensors[ti.name] = ti;
    }
    long pos = ftell(ctx.fp);
    ctx.data_offset = (uint64_t)(((pos + 31) / 32) * 32);
    return true;
}

static std::vector<float> gguf_load_tensor(GgufContext& ctx, const std::string& name) {
    auto it = ctx.tensors.find(name);
    if (it == ctx.tensors.end()) { YLOG("Tensor not found: %s\n", name.c_str()); return {}; }
    const TensorInfo& ti = it->second;
    uint64_t n = 1;
    for (auto s : ti.shape) n *= s;
    std::vector<float> out(n);
    long file_pos = (long)(ctx.data_offset + ti.offset);
    if (fseek(ctx.fp, file_pos, SEEK_SET) != 0) {
        YLOG("Cannot seek to tensor %s\n", name.c_str());
        return {};
    }
    if (ti.dtype == GGML_F32) {
        if (fread(out.data(), 4, n, ctx.fp) != n) {
            YLOG("Short read for tensor %s\n", name.c_str());
            return {};
        }
    } else if (ti.dtype == GGML_F16) {
        std::vector<uint16_t> raw(n);
        if (fread(raw.data(), 2, n, ctx.fp) != n) {
            YLOG("Short read for tensor %s\n", name.c_str());
            return {};
        }
        for (uint64_t i = 0; i < n; i++) out[i] = f16_to_f32(raw[i]);
    } else {
        YLOG("Unsupported dtype %u for %s\n", ti.dtype, name.c_str());
        return {};
    }
    return out;
}

static inline float rms_norm_scalar(const float* x, int n, float eps) {
    float sum = 0; for (int i = 0; i < n; i++) sum += x[i] * x[i];
    return 1.0f / std::sqrt(sum / n + eps);
}
static void rms_norm(float* out, const float* x, const float* w, int n, float eps) {
    float scale = rms_norm_scalar(x, n, eps);
    for (int i = 0; i < n; i++) out[i] = w[i] * x[i] * scale;
}
static void matvec(float* out, const float* mat, const float* vec, int out_dim, int in_dim) {
    for (int i = 0; i < out_dim; i++) {
        float s = 0; const float* row = mat + (long long)i * in_dim;
        for (int j = 0; j < in_dim; j++) s += row[j] * vec[j];
        out[i] = s;
    }
}
static inline float sigmoid(float x) { return 1.0f / (1.0f + std::exp(-x)); }
static inline float silu(float x) { return x * sigmoid(x); }
static inline float softplus(float x) { return (x > 20.0f) ? x : std::log1p(std::exp(x)); }
static inline float clamped_swiglu(float gate, float up) {
    return std::min(silu(gate), SWIGLU_CLAMP) * std::max(-SWIGLU_CLAMP, std::min(up, SWIGLU_CLAMP));
}
static void l2norm(float* x, int n, float eps = 1e-6f) {
    float sum = 0; for (int i = 0; i < n; i++) sum += x[i] * x[i];
    float scale = 1.0f / std::sqrt(sum + eps);
    for (int i = 0; i < n; i++) x[i] *= scale;
}

struct GdnWeights {
    std::vector<float> in_qkv, in_z, in_b, in_a, conv1d, dt_bias, A_log, norm_w, out_proj, attn_norm;
};
struct AttnWeights {
    std::vector<float> q, k, v, q_norm_w, k_norm_w, out_proj, attn_norm;
};
struct MoeWeights {
    std::vector<float> gate_w, gate_bias, hash_proj, sh_gate, sh_up, sh_down, sh_scale;
    std::vector<float> ex_gate, ex_up, ex_down, ffn_norm;
    bool is_hash;
};
struct Model {
    int vocab_size = 0;
    std::vector<float> embed, out_norm, rope_cos, rope_sin;
    GdnWeights gdn[N_LAYERS];
    AttnWeights attn;
    MoeWeights moe[N_LAYERS];
};
static Model* g_model = nullptr;
static void clear_prefix_cache();

static std::string tn(int layer, const char* suffix) {
    char buf[128]; snprintf(buf, sizeof(buf), "blk.%d.%s", layer, suffix); return buf;
}

static bool load_exact(GgufContext& ctx, const std::string& name, size_t expected, std::vector<float>& out) {
    out = gguf_load_tensor(ctx, name);
    if (out.size() != expected) {
        YLOG("Tensor %s has %zu elements, expected %zu\n", name.c_str(), out.size(), expected);
        return false;
    }
    return true;
}

static bool load_weights(GgufContext& ctx, Model* m) {
    const size_t D = D_MODEL;
    const size_t CDIM = (size_t)GDN_HEADS * GDN_HEAD_DIM * 3;
    const size_t expert_size = (size_t)EXPERT_HIDDEN * D_MODEL;
    if (!load_exact(ctx, "token_embd.weight", (size_t)m->vocab_size * D, m->embed)) return false;
    if (!load_exact(ctx, "output_norm.weight", D, m->out_norm)) return false;
    for (int i = 0; i < N_LAYERS; i++) {
        if (layer_is_gdn(i)) {
            GdnWeights& g = m->gdn[i];
            if (!load_exact(ctx, tn(i, "ssm_in.weight"), CDIM * D, g.in_qkv)) return false;
            if (!load_exact(ctx, tn(i, "ssm_z.weight"), (size_t)GDN_HEADS * GDN_HEAD_DIM * D, g.in_z)) return false;
            if (!load_exact(ctx, tn(i, "ssm_b.weight"), (size_t)GDN_HEADS * D, g.in_b)) return false;
            if (!load_exact(ctx, tn(i, "ssm_a.weight"), (size_t)GDN_HEADS * D, g.in_a)) return false;
            if (!load_exact(ctx, tn(i, "ssm_conv1d.weight"), CDIM * CONV_KERNEL, g.conv1d)) return false;
            if (!load_exact(ctx, tn(i, "ssm_dt.bias"), GDN_HEADS, g.dt_bias)) return false;
            if (!load_exact(ctx, tn(i, "ssm_a_log"), GDN_HEADS, g.A_log)) return false;
            if (!load_exact(ctx, tn(i, "ssm_norm.weight"), GDN_HEAD_DIM, g.norm_w)) return false;
            if (!load_exact(ctx, tn(i, "ssm_out.weight"), D * D, g.out_proj)) return false;
            if (!load_exact(ctx, tn(i, "attn_norm.weight"), D, g.attn_norm)) return false;
        } else {
            AttnWeights& a = m->attn;
            if (!load_exact(ctx, tn(i, "attn_q.weight"), (size_t)N_HEADS * HEAD_DIM * 2 * D, a.q)) return false;
            if (!load_exact(ctx, tn(i, "attn_k.weight"), (size_t)N_KV_HEADS * HEAD_DIM * D, a.k)) return false;
            if (!load_exact(ctx, tn(i, "attn_v.weight"), (size_t)N_KV_HEADS * HEAD_DIM * D, a.v)) return false;
            if (!load_exact(ctx, tn(i, "attn_q_norm.weight"), HEAD_DIM, a.q_norm_w)) return false;
            if (!load_exact(ctx, tn(i, "attn_k_norm.weight"), HEAD_DIM, a.k_norm_w)) return false;
            if (!load_exact(ctx, tn(i, "attn_output.weight"), D * N_HEADS * HEAD_DIM, a.out_proj)) return false;
            if (!load_exact(ctx, tn(i, "attn_norm.weight"), D, a.attn_norm)) return false;
        }
        MoeWeights& mw = m->moe[i];
        mw.is_hash = (i < HASH_LAYERS);
        if (mw.is_hash) {
            if (!load_exact(ctx, tn(i, "ffn_hash_proj"), (size_t)N_EXPERTS * D, mw.hash_proj)) return false;
        } else {
            if (!load_exact(ctx, tn(i, "ffn_gate_inp.weight"), (size_t)N_EXPERTS * D, mw.gate_w)) return false;
            if (!load_exact(ctx, tn(i, "ffn_gate_inp.bias"), N_EXPERTS, mw.gate_bias)) return false;
        }
        if (!load_exact(ctx, tn(i, "ffn_gate_shexp.weight"), expert_size, mw.sh_gate)) return false;
        if (!load_exact(ctx, tn(i, "ffn_up_shexp.weight"), expert_size, mw.sh_up)) return false;
        if (!load_exact(ctx, tn(i, "ffn_down_shexp.weight"), expert_size, mw.sh_down)) return false;
        if (!load_exact(ctx, tn(i, "ffn_gate_shexp_scale.weight"), D, mw.sh_scale)) return false;
        if (!load_exact(ctx, tn(i, "ffn_norm.weight"), D, mw.ffn_norm)) return false;
        mw.ex_gate.resize((size_t)N_EXPERTS * expert_size);
        mw.ex_up.resize((size_t)N_EXPERTS * expert_size);
        mw.ex_down.resize((size_t)N_EXPERTS * expert_size);
        std::vector<float> tensor_data;
        for (int e = 0; e < N_EXPERTS; e++) {
            char buf[64];
            const size_t offset = (size_t)e * expert_size;
            snprintf(buf, sizeof(buf), "ffn_gate_exps.%d.weight", e);
            if (!load_exact(ctx, tn(i, buf), expert_size, tensor_data)) return false;
            std::copy(tensor_data.begin(), tensor_data.end(), mw.ex_gate.begin() + offset);
            snprintf(buf, sizeof(buf), "ffn_up_exps.%d.weight", e);
            if (!load_exact(ctx, tn(i, buf), expert_size, tensor_data)) return false;
            std::copy(tensor_data.begin(), tensor_data.end(), mw.ex_up.begin() + offset);
            snprintf(buf, sizeof(buf), "ffn_down_exps.%d.weight", e);
            if (!load_exact(ctx, tn(i, buf), expert_size, tensor_data)) return false;
            std::copy(tensor_data.begin(), tensor_data.end(), mw.ex_down.begin() + offset);
        }
    }
    return true;
}

static bool load_model(const char* path) {
    GgufContext ctx;
    if (!gguf_open(ctx, path)) return false;
    if (ctx.vocab_size <= 0) { YLOG("vocab_size not found in GGUF metadata\n"); return false; }
    Model* m = new Model();
    m->vocab_size = ctx.vocab_size;
    if (!load_weights(ctx, m)) { delete m; return false; }
    int max_seq = ROPE_MAX; float theta = 10000.0f;
    m->rope_cos.resize(max_seq * ROPE_HALF);
    m->rope_sin.resize(max_seq * ROPE_HALF);
    for (int pos = 0; pos < max_seq; pos++) {
        for (int i = 0; i < ROPE_HALF; i++) {
            float freq = 1.0f / std::pow(theta, (float)(2 * i) / ROPE_DIMS);
            float angle = pos * freq;
            m->rope_cos[pos * ROPE_HALF + i] = std::cos(angle);
            m->rope_sin[pos * ROPE_HALF + i] = std::sin(angle);
        }
    }
    g_model = m;
    YLOG("Model loaded (vocab=%d)\n", m->vocab_size);
    return true;
}

static void gdn_forward_one(const GdnWeights& w, const float* x, float* out,
    float state[GDN_HEADS][GDN_HEAD_DIM][GDN_HEAD_DIM],
    float conv_buf[CONV_KERNEL - 1][GDN_HEADS * GDN_HEAD_DIM * 3]) {
    const int CDIM = GDN_HEADS * GDN_HEAD_DIM * 3;
    float qkv_raw[CDIM];
    matvec(qkv_raw, w.in_qkv.data(), x, CDIM, D_MODEL);
    float qkv[CDIM];
    for (int c = 0; c < CDIM; c++) {
        float s = 0;
        for (int k = 0; k < CONV_KERNEL - 1; k++) s += conv_buf[k][c] * w.conv1d[c * CONV_KERNEL + k];
        s += qkv_raw[c] * w.conv1d[c * CONV_KERNEL + (CONV_KERNEL - 1)];
        qkv[c] = silu(s);
    }
    for (int k = 0; k < CONV_KERNEL - 2; k++) std::memcpy(conv_buf[k], conv_buf[k + 1], CDIM * sizeof(float));
    std::memcpy(conv_buf[CONV_KERNEL - 2], qkv_raw, CDIM * sizeof(float));
    const float* q_all = qkv;
    const float* k_all = qkv + GDN_HEADS * GDN_HEAD_DIM;
    const float* v_all = qkv + GDN_HEADS * GDN_HEAD_DIM * 2;
    float beta_raw[GDN_HEADS], alpha_raw[GDN_HEADS];
    matvec(beta_raw, w.in_b.data(), x, GDN_HEADS, D_MODEL);
    matvec(alpha_raw, w.in_a.data(), x, GDN_HEADS, D_MODEL);
    float beta[GDN_HEADS], g_decay[GDN_HEADS];
    for (int h = 0; h < GDN_HEADS; h++) {
        beta[h] = sigmoid(beta_raw[h]);
        float g = -std::exp(w.A_log[h]) * softplus(alpha_raw[h] + w.dt_bias[h]);
        g_decay[h] = std::exp(g);
    }
    float y[GDN_HEADS * GDN_HEAD_DIM];
    float k_norm[GDN_HEAD_DIM], k_cum_h[GDN_HEAD_DIM], retrieved[GDN_HEAD_DIM], vn[GDN_HEAD_DIM], q_dec[GDN_HEAD_DIM];
    float scale = 1.0f / std::sqrt((float)GDN_HEAD_DIM);
    for (int h = 0; h < GDN_HEADS; h++) {
        const float* kh = k_all + h * GDN_HEAD_DIM;
        const float* vh = v_all + h * GDN_HEAD_DIM;
        const float* qh = q_all + h * GDN_HEAD_DIM;
        float* state_h = state[h][0];
        float bd = beta[h]; float decay = g_decay[h];
        std::memcpy(k_norm, kh, GDN_HEAD_DIM * sizeof(float));
        l2norm(k_norm, GDN_HEAD_DIM);
        float q_scaled[GDN_HEAD_DIM];
        std::memcpy(q_scaled, qh, GDN_HEAD_DIM * sizeof(float));
        l2norm(q_scaled, GDN_HEAD_DIM);
        for (int i = 0; i < GDN_HEAD_DIM; i++) { q_scaled[i] *= scale; q_dec[i] = q_scaled[i] * decay; }
        for (int i = 0; i < GDN_HEAD_DIM; i++) k_cum_h[i] = k_norm[i] * bd * decay;
        for (int j = 0; j < GDN_HEAD_DIM; j++) {
            float s = 0; for (int i = 0; i < GDN_HEAD_DIM; i++) s += k_cum_h[i] * state_h[i * GDN_HEAD_DIM + j];
            retrieved[j] = s;
        }
        for (int j = 0; j < GDN_HEAD_DIM; j++) vn[j] = vh[j] * bd - retrieved[j];
        float attn_score = 0;
        for (int i = 0; i < GDN_HEAD_DIM; i++) attn_score += q_scaled[i] * k_norm[i];
        for (int j = 0; j < GDN_HEAD_DIM; j++) {
            float s = 0; for (int i = 0; i < GDN_HEAD_DIM; i++) s += q_dec[i] * state_h[i * GDN_HEAD_DIM + j];
            y[h * GDN_HEAD_DIM + j] = s + attn_score * vn[j];
        }
        for (int i = 0; i < GDN_HEAD_DIM * GDN_HEAD_DIM; i++) state_h[i] *= decay;
        for (int i = 0; i < GDN_HEAD_DIM; i++) {
            float ki = k_norm[i]; float* row = state_h + i * GDN_HEAD_DIM;
            for (int j = 0; j < GDN_HEAD_DIM; j++) row[j] += ki * vn[j];
        }
    }
    float z[GDN_HEADS * GDN_HEAD_DIM];
    matvec(z, w.in_z.data(), x, GDN_HEADS * GDN_HEAD_DIM, D_MODEL);
    float y_gated[GDN_HEADS * GDN_HEAD_DIM];
    for (int h = 0; h < GDN_HEADS; h++) {
        float* yh = y + h * GDN_HEAD_DIM; float* zh = z + h * GDN_HEAD_DIM;
        float rms_scale = rms_norm_scalar(yh, GDN_HEAD_DIM, NORM_EPS);
        for (int i = 0; i < GDN_HEAD_DIM; i++)
            y_gated[h * GDN_HEAD_DIM + i] = w.norm_w[i] * yh[i] * rms_scale * silu(zh[i]);
    }
    matvec(out, w.out_proj.data(), y_gated, D_MODEL, D_MODEL);
}

static bool apply_rope(float* x, int pos, int n_heads, const std::vector<float>& cos, const std::vector<float>& sin) {
    const size_t row = ROPE_HALF;
    if (pos < 0 || (size_t)(pos + 1) * row > cos.size() || (size_t)(pos + 1) * row > sin.size()) return false;
    const float* c = cos.data() + (size_t)pos * row;
    const float* s = sin.data() + (size_t)pos * row;
    for (int h = 0; h < n_heads; h++) {
        float* xh = x + h * HEAD_DIM;
        for (int i = 0; i < ROPE_HALF; i++) {
            float x0 = xh[i], x1 = xh[i + ROPE_HALF];
            xh[i] = x0 * c[i] - x1 * s[i];
            xh[i + ROPE_HALF] = x1 * c[i] + x0 * s[i];
        }
    }
    return true;
}

static void moe_forward_one(const MoeWeights& w, const float* x, float* out) {
    float scores[N_EXPERTS];
    if (w.is_hash) {
        for (int e = 0; e < N_EXPERTS; e++) {
            float s = 0;
            for (int d = 0; d < D_MODEL; d++) s += x[d] * w.hash_proj[(size_t)d * N_EXPERTS + e];
            scores[e] = s;
        }
    } else {
        matvec(scores, w.gate_w.data(), x, N_EXPERTS, D_MODEL);
        for (int e = 0; e < N_EXPERTS; e++) scores[e] = std::sqrt(softplus(scores[e])) + w.gate_bias[e];
    }
    int best = 0; for (int e = 1; e < N_EXPERTS; e++) if (scores[e] > scores[best]) best = e;
    float shgate[EXPERT_HIDDEN], shup[EXPERT_HIDDEN], sh_out[D_MODEL];
    matvec(shgate, w.sh_gate.data(), x, EXPERT_HIDDEN, D_MODEL);
    matvec(shup, w.sh_up.data(), x, EXPERT_HIDDEN, D_MODEL);
    for (int i = 0; i < EXPERT_HIDDEN; i++) shgate[i] = clamped_swiglu(shgate[i], shup[i]);
    float sh_sig_val = 0;
    for (int i = 0; i < D_MODEL; i++) sh_sig_val += w.sh_scale[i] * x[i];
    float sh_sig = sigmoid(sh_sig_val);
    matvec(sh_out, w.sh_down.data(), shgate, D_MODEL, EXPERT_HIDDEN);
    for (int i = 0; i < D_MODEL; i++) sh_out[i] *= sh_sig;
    float exgate[EXPERT_HIDDEN], exup[EXPERT_HIDDEN], ex_out[D_MODEL];
    const float* eg = w.ex_gate.data() + (long long)best * EXPERT_HIDDEN * D_MODEL;
    const float* eu = w.ex_up.data() + (long long)best * EXPERT_HIDDEN * D_MODEL;
    const float* ed = w.ex_down.data() + (long long)best * D_MODEL * EXPERT_HIDDEN;
    matvec(exgate, eg, x, EXPERT_HIDDEN, D_MODEL);
    matvec(exup, eu, x, EXPERT_HIDDEN, D_MODEL);
    for (int i = 0; i < EXPERT_HIDDEN; i++) exgate[i] = clamped_swiglu(exgate[i], exup[i]);
    matvec(ex_out, ed, exgate, D_MODEL, EXPERT_HIDDEN);
    for (int i = 0; i < D_MODEL; i++) out[i] = sh_out[i] + ex_out[i];
}

struct InferenceState {
    std::vector<float> key_cache;
    std::vector<float> value_cache;
    int cached_count = 0;
    int cache_start = 0;
    float gdn_states[N_LAYERS][GDN_HEADS][GDN_HEAD_DIM * GDN_HEAD_DIM];
    float conv_buffers[N_LAYERS][CONV_KERNEL - 1][GDN_HEADS * GDN_HEAD_DIM * 3];

    void reset() {
        key_cache.assign((size_t)ATTN_WINDOW * N_KV_HEADS * HEAD_DIM, 0.0f);
        value_cache.assign((size_t)ATTN_WINDOW * N_KV_HEADS * HEAD_DIM, 0.0f);
        cached_count = 0;
        cache_start = 0;
        std::memset(gdn_states, 0, sizeof(gdn_states));
        std::memset(conv_buffers, 0, sizeof(conv_buffers));
    }
};

static std::mutex g_generate_mutex;
static std::vector<int> g_prefix_tokens;
static InferenceState* g_prefix_state = nullptr;

static void clear_prefix_cache() {
    g_prefix_tokens.clear();
    delete g_prefix_state;
    g_prefix_state = nullptr;
}

static bool attn_forward_token(const AttnWeights& w, const float* x, float* out, int pos,
                               const Model& m, InferenceState& state) {
    const int kv_row = N_KV_HEADS * HEAD_DIM;
    float qg[N_HEADS * HEAD_DIM * 2];
    matvec(qg, w.q.data(), x, N_HEADS * HEAD_DIM * 2, D_MODEL);
    float query[N_HEADS * HEAD_DIM];
    float out_gate[N_HEADS * HEAD_DIM];
    for (int h = 0; h < N_HEADS; h++) {
        float* qh = qg + h * HEAD_DIM * 2;
        float* gh = qh + HEAD_DIM;
        float rms_q = rms_norm_scalar(qh, HEAD_DIM, NORM_EPS);
        for (int i = 0; i < HEAD_DIM; i++) {
            query[h * HEAD_DIM + i] = w.q_norm_w[i] * qh[i] * rms_q;
            out_gate[h * HEAD_DIM + i] = sigmoid(gh[i]);
        }
    }
    if (!apply_rope(query, pos, N_HEADS, m.rope_cos, m.rope_sin)) return false;

    float key[N_KV_HEADS * HEAD_DIM];
    matvec(key, w.k.data(), x, kv_row, D_MODEL);
    for (int h = 0; h < N_KV_HEADS; h++) {
        float* kh = key + h * HEAD_DIM;
        float rms_k = rms_norm_scalar(kh, HEAD_DIM, NORM_EPS);
        for (int i = 0; i < HEAD_DIM; i++) kh[i] = w.k_norm_w[i] * kh[i] * rms_k;
    }
    if (!apply_rope(key, pos, N_KV_HEADS, m.rope_cos, m.rope_sin)) return false;

    float value[N_KV_HEADS * HEAD_DIM];
    matvec(value, w.v.data(), x, kv_row, D_MODEL);

    int slot;
    if (state.cached_count < ATTN_WINDOW) {
        slot = (state.cache_start + state.cached_count) % ATTN_WINDOW;
        state.cached_count++;
    } else {
        slot = state.cache_start;
        state.cache_start = (state.cache_start + 1) % ATTN_WINDOW;
    }
    std::memcpy(state.key_cache.data() + (size_t)slot * kv_row, key, kv_row * sizeof(float));
    std::memcpy(state.value_cache.data() + (size_t)slot * kv_row, value, kv_row * sizeof(float));

    const float scale = 1.0f / std::sqrt((float)HEAD_DIM);
    float scores[ATTN_WINDOW];
    float y[N_HEADS * HEAD_DIM];
    std::fill(y, y + N_HEADS * HEAD_DIM, 0.0f);
    for (int h = 0; h < N_HEADS; h++) {
        const float* qh = query + h * HEAD_DIM;
        const int kv_head = h / (N_HEADS / N_KV_HEADS);
        float max_score = -1e30f;
        for (int s = 0; s < state.cached_count; s++) {
            const int entry = (state.cache_start + s) % ATTN_WINDOW;
            const float* kh = state.key_cache.data() + (size_t)entry * kv_row + kv_head * HEAD_DIM;
            float score = 0;
            for (int i = 0; i < HEAD_DIM; i++) score += qh[i] * kh[i];
            scores[s] = score * scale;
            if (scores[s] > max_score) max_score = scores[s];
        }
        float total = 0;
        for (int s = 0; s < state.cached_count; s++) {
            scores[s] = std::exp(scores[s] - max_score);
            total += scores[s];
        }
        float* yh = y + h * HEAD_DIM;
        for (int s = 0; s < state.cached_count; s++) {
            const int entry = (state.cache_start + s) % ATTN_WINDOW;
            const float* vh = state.value_cache.data() + (size_t)entry * kv_row + kv_head * HEAD_DIM;
            const float weight = scores[s] / total;
            for (int i = 0; i < HEAD_DIM; i++) yh[i] += weight * vh[i];
        }
    }
    for (int i = 0; i < N_HEADS * HEAD_DIM; i++) y[i] *= out_gate[i];
    matvec(out, w.out_proj.data(), y, D_MODEL, N_HEADS * HEAD_DIM);
    return true;
}

static bool forward_token(Model& m, InferenceState& state, int token, int pos, std::vector<float>& logits) {
    int id = token; if (id < 0 || id >= m.vocab_size) id = 0;
    std::vector<float> hidden(m.embed.begin() + (size_t)id * D_MODEL,
                              m.embed.begin() + (size_t)(id + 1) * D_MODEL);
    std::vector<float> normed(D_MODEL), attn_out(D_MODEL);
    std::vector<float> moe_in(D_MODEL), moe_out(D_MODEL), gdn_out(D_MODEL);
    for (int layer = 0; layer < N_LAYERS; layer++) {
        const MoeWeights& mw = m.moe[layer];
        if (layer_is_gdn(layer)) {
            const GdnWeights& gw = m.gdn[layer];
            float (*gdn_state)[GDN_HEAD_DIM * GDN_HEAD_DIM] = state.gdn_states[layer];
            float (*conv_buffer)[GDN_HEADS * GDN_HEAD_DIM * 3] = state.conv_buffers[layer];
            rms_norm(normed.data(), hidden.data(), gw.attn_norm.data(), D_MODEL, NORM_EPS);
            float token_state[GDN_HEADS][GDN_HEAD_DIM][GDN_HEAD_DIM];
            for (int h = 0; h < GDN_HEADS; h++)
                std::memcpy(token_state[h], gdn_state[h], GDN_HEAD_DIM * GDN_HEAD_DIM * sizeof(float));
            gdn_forward_one(gw, normed.data(), gdn_out.data(), token_state,
                reinterpret_cast<float(*)[GDN_HEADS*GDN_HEAD_DIM*3]>(conv_buffer));
            for (int h = 0; h < GDN_HEADS; h++)
                std::memcpy(gdn_state[h], token_state[h], GDN_HEAD_DIM * GDN_HEAD_DIM * sizeof(float));
            for (int i = 0; i < D_MODEL; i++) hidden[i] += gdn_out[i];
        } else {
            const AttnWeights& aw = m.attn;
            rms_norm(normed.data(), hidden.data(), aw.attn_norm.data(), D_MODEL, NORM_EPS);
            if (!attn_forward_token(aw, normed.data(), attn_out.data(), pos, m, state)) return false;
            for (int i = 0; i < D_MODEL; i++) hidden[i] += attn_out[i];
        }
        rms_norm(moe_in.data(), hidden.data(), mw.ffn_norm.data(), D_MODEL, NORM_EPS);
        moe_forward_one(mw, moe_in.data(), moe_out.data());
        for (int i = 0; i < D_MODEL; i++) hidden[i] += moe_out[i];
    }
    rms_norm(normed.data(), hidden.data(), m.out_norm.data(), D_MODEL, NORM_EPS);
    logits.resize(m.vocab_size);
    for (int v = 0; v < m.vocab_size; v++) {
        float sum = 0; const float* ev = m.embed.data() + (size_t)v * D_MODEL;
        for (int i = 0; i < D_MODEL; i++) sum += ev[i] * normed[i];
        logits[v] = sum;
    }
    return true;
}

extern "C" {

int ytteria_load(const char* gguf_path) {
    YLOG("ytteria_load called: %s\n", gguf_path);
    std::lock_guard<std::mutex> lock(g_generate_mutex);
    clear_prefix_cache();
    if (g_model) { delete g_model; g_model = nullptr; }
    return load_model(gguf_path) ? 1 : 0;
}

void ytteria_unload() {
    std::lock_guard<std::mutex> lock(g_generate_mutex);
    clear_prefix_cache();
    delete g_model;
    g_model = nullptr;
}

int ytteria_is_loaded() { return g_model ? 1 : 0; }

int ytteria_generate(const int* input_ids, int n_input, int* output_ids, int max_new, int eos_id, int stop_id2, int prefix_len) {
    std::lock_guard<std::mutex> lock(g_generate_mutex);
    if (!g_model || n_input <= 0 || max_new <= 0) return -1;
    if (n_input + max_new > ROPE_MAX) {
        if (n_input >= ROPE_MAX - 1) {
            input_ids += n_input - (ROPE_MAX - 1);
            n_input = ROPE_MAX - 1;
        }
        max_new = std::min(max_new, ROPE_MAX - n_input);
    }
    if (max_new <= 0) return -1;

    const bool use_prefix_cache = prefix_len > 0 && prefix_len < n_input;
    const bool prefix_cached = use_prefix_cache && g_prefix_state != nullptr &&
        (int)g_prefix_tokens.size() == prefix_len &&
        std::equal(g_prefix_tokens.begin(), g_prefix_tokens.end(), input_ids);

    InferenceState state;
    std::vector<float> logits;
    int pos = 0;
    if (prefix_cached) {
        state = *g_prefix_state;
        pos = prefix_len;
    } else {
        state.reset();
    }
    for (int i = pos; i < n_input; i++) {
        if (use_prefix_cache && !prefix_cached && i == prefix_len) {
            clear_prefix_cache();
            g_prefix_state = new InferenceState(state);
            g_prefix_tokens.assign(input_ids, input_ids + prefix_len);
        }
        if (!forward_token(*g_model, state, input_ids[i], pos, logits)) return -1;
        pos++;
    }

    int n_gen = 0;
    while (n_gen < max_new) {
        if (logits.empty()) return -1;
        int next = 0; float best = logits[0];
        for (int i = 1; i < (int)logits.size(); i++) { if (logits[i] > best) { best = logits[i]; next = i; } }
        output_ids[n_gen++] = next;
        if (next == eos_id || next == stop_id2) break;
        if (pos >= ROPE_MAX) break;
        if (!forward_token(*g_model, state, next, pos, logits)) return -1;
        pos++;
    }
    return n_gen;
}

}
