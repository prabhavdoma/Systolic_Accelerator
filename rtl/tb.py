import numpy as np
import random

N = 16
cycles = 3 * N

random.seed(1)
np.random.seed(1)

# ---------------------------------------------------------------- array stim
A = np.random.randint(-128, 128, (N, N)).astype(np.int8)
B = np.random.randint(-128, 128, (N, N)).astype(np.int8)

C_golden = A.astype(np.int32) @ B.astype(np.int32)

# skewed streams (kept for the standalone skew_regs test)
a_stream = np.zeros((cycles, N), dtype=np.int8)
b_stream = np.zeros((cycles, N), dtype=np.int8)
for i in range(N):
    for k in range(N):
        a_stream[k + i][i] = A[i][k]
for j in range(N):
    for k in range(N):
        b_stream[k + j][j] = B[k][j]

with open("a_stream.hex", "w") as f:
    for c in range(cycles):
        for i in range(N):
            f.write(f"{int(a_stream[c][i]) & 0xFF:02x}\n")

with open("b_stream.hex", "w") as f:
    for c in range(cycles):
        for j in range(N):
            f.write(f"{int(b_stream[c][j]) & 0xFF:02x}\n")

# flat streams: on cycle k, row i carries A[i][k], col j carries B[k][j]
with open("a_raw.hex", "w") as f:
    for k in range(N):
        for i in range(N):
            f.write(f"{int(A[i][k]) & 0xFF:02x}\n")

with open("b_raw.hex", "w") as f:
    for k in range(N):
        for j in range(N):
            f.write(f"{int(B[k][j]) & 0xFF:02x}\n")

with open("golden.hex", "w") as f:
    for i in range(N):
        for j in range(N):
            f.write(f"{int(C_golden[i][j]) & 0xFFFFFFFF:08x}\n")

print("A[0][:4] =", A[0][:4])
print("C[0][:4] =", C_golden[0][:4])
print("|C| max  =", int(np.abs(C_golden).max()))


# ------------------------------------------------------------ requant model
# Mirrors requant.sv exactly. Plain Python ints only - numpy would wrap
# silently at 64 bits and hide the very bug this model exists to catch.
def requant(acc, bias, m, s, relu_en):
    v = acc + bias
    v = v * m
    v = v + ((1 << (s - 1)) if s > 0 else 0)
    v = v >> s                      # Python >> floors on negatives, same as >>>
    lo = 0 if relu_en else -128
    return max(lo, min(127, v))


def s64(x):
    """What a 64-bit signed register would actually hold."""
    x &= (1 << 64) - 1
    return x - (1 << 64) if x >> 63 else x


def make_m_s(M, mbits=31):
    """Decompose real scale M into (m, s) with m normalised near 2^(mbits-1).
    m stays inside signed-32 range."""
    s = 0
    m = M
    while m < (1 << (mbits - 1)):
        m *= 2
        s += 1
    return int(round(m)), s


# a realistic scale: acc at s_a*s_b, output at s_c
M_TYPICAL = 0.002
m_typ, s_typ = make_m_s(M_TYPICAL)
print(f"M={M_TYPICAL} -> m={m_typ} (0x{m_typ:08x}), s={s_typ}")
assert m_typ < (1 << 31), "m must fit in signed 32"

cases = []


def add_case(name, acc, bias, m, s, relu):
    assert len(acc) == N and len(bias) == N
    for a, b in zip(acc, bias):
        prod = s64((a + b) * m)
        assert prod == (a + b) * m, f"{name}: 64-bit overflow in acc*m"
    cases.append(dict(name=name, acc=acc, bias=bias, m=m, s=s, relu=relu))


z = [0] * N

# 1. all zeros - nothing should move
add_case("zeros", z, z, m_typ, s_typ, 0)

# 2. real accumulator values off the array, small biases
add_case("typical",
         [int(C_golden[0][j]) for j in range(N)],
         [random.randint(-5000, 5000) for _ in range(N)],
         m_typ, s_typ, 0)

# 3. saturate high in every lane
add_case("sat_high", [1 << 29] * N, z, m_typ, s_typ, 0)

# 4. saturate low in every lane
add_case("sat_low", [-(1 << 29)] * N, z, m_typ, s_typ, 0)

# 5. negatives with relu on - every lane should pin to 0
add_case("relu_neg", [-(1000 * (j + 1)) for j in range(N)], z, m_typ, s_typ, 1)

# 6. relu on, positives pass through untouched
add_case("relu_pos", [1000 * (j + 1) for j in range(N)], z, m_typ, s_typ, 1)

# 7. rounding boundary sweep: m=1, s=4 means low 4 bits decide the round.
#    lanes 0-7 round down, 8-15 round up.
add_case("round_bnd", list(range(N)), z, 1, 4, 0)

# 8. same sweep on the negative side - this is where >>> vs >> diverges
add_case("round_bnd_neg", [-j for j in range(N)], z, 1, 4, 0)

# 9. s=0: no shift, no rounding constant, clamp only
add_case("s_zero", [-200 + 30 * j for j in range(N)], z, 1, 0, 0)

# 10. largest m that fits signed 32
add_case("m_max", [random.randint(-(1 << 20), 1 << 20) for _ in range(N)],
         z, (1 << 31) - 1, s_typ, 0)

# 11. bias does all the work
add_case("bias_only", z, [random.randint(-(1 << 22), 1 << 22) for _ in range(N)],
         m_typ, s_typ, 0)

# 12. wide random
add_case("random_wide",
         [random.randint(-(1 << 27), 1 << 27) for _ in range(N)],
         [random.randint(-(1 << 20), 1 << 20) for _ in range(N)],
         random.randint(1 << 30, (1 << 31) - 1), random.randint(36, 45), 0)

NCASES = len(cases)
print(f"requant cases: {NCASES}")

with open("rq_acc.hex", "w") as fa, \
     open("rq_bias.hex", "w") as fb, \
     open("rq_m.hex", "w") as fm, \
     open("rq_s.hex", "w") as fs, \
     open("rq_relu.hex", "w") as fr, \
     open("rq_exp.hex", "w") as fe, \
     open("rq_cases.txt", "w") as fn:

    for idx, c in enumerate(cases):
        fm.write(f"{c['m'] & 0xFFFFFFFF:08x}\n")
        fs.write(f"{c['s'] & 0xFF:02x}\n")
        fr.write(f"{c['relu'] & 0xFF:02x}\n")
        fn.write(f"{idx} {c['name']}\n")
        for j in range(N):
            fa.write(f"{c['acc'][j]  & 0xFFFFFFFF:08x}\n")
            fb.write(f"{c['bias'][j] & 0xFFFFFFFF:08x}\n")
            e = requant(c['acc'][j], c['bias'][j], c['m'], c['s'], c['relu'])
            fe.write(f"{e & 0xFF:02x}\n")

for idx, c in enumerate(cases):
    got = [requant(c['acc'][j], c['bias'][j], c['m'], c['s'], c['relu'])
           for j in range(N)]
    print(f"  {idx:2d} {c['name']:<14} m={c['m']:<11} s={c['s']:<3} "
          f"relu={c['relu']}  out[0:6]={got[:6]}")