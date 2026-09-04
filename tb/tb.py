import numpy as np

N = 16
cycles = 3 * N  # enough time for data to flow through

# Random INT8 matrices
A = np.random.randint(-10, 10, (N, N), dtype=np.int8)
B = np.random.randint(-10, 10, (N, N), dtype=np.int8)

# Golden result
C_golden = A.astype(np.int32) @ B.astype(np.int32)

# Build skewed input streams
a_stream = np.zeros((cycles, N), dtype=np.int8)
b_stream = np.zeros((cycles, N), dtype=np.int8)

for i in range(N):
    for k in range(N):
        a_stream[k + i][i] = A[i][k]  # row i starts k cycles in, delayed by i

for j in range(N):
    for k in range(N):
        b_stream[k + j][j] = B[k][j]  # col j delayed by j

print("Golden C[0][0]:", C_golden[0][0])
print("Golden C[0][1]:", C_golden[0][1])
print("A stream col 0 (first 5 cycles):", a_stream[:5, 0])
print("B stream col 0 (first 5 cycles):", b_stream[:5, 0])

# Write a_stream to file
with open("a_stream.hex", "w") as f:
    for cycle in range(cycles):
        for i in range(N):
            val = int(a_stream[cycle][i]) & 0xFF  # keep as unsigned byte
            f.write(f"{val:02x}\n")

# Write b_stream to file
with open("b_stream.hex", "w") as f:
    for cycle in range(cycles):
        for j in range(N):
            val = int(b_stream[cycle][j]) & 0xFF
            f.write(f"{val:02x}\n")

# Write golden C to file
with open("golden.hex", "w") as f:
    for i in range(N):
        for j in range(N):
            val = int(C_golden[i][j]) & 0xFFFFFFFF  # 32-bit
            f.write(f"{val:08x}\n")