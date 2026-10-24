import sys, wave, numpy as np
src, dst = sys.argv[1], sys.argv[2]
w = wave.open(src)
ch, sw, sr, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
raw = w.readframes(n)
if sw == 2: a = np.frombuffer(raw, np.int16).astype(np.float32) / 32768
elif sw == 3:
    b = np.frombuffer(raw, np.uint8).reshape(-1, 3)
    a = (b[:,0].astype(np.int32) | (b[:,1].astype(np.int32) << 8) | (b[:,2].astype(np.int32) << 16))
    a = np.where(a >= 1 << 23, a - (1 << 24), a).astype(np.float32) / (1 << 23)
else: raise SystemExit("unsupported width %d" % sw)
a = a.reshape(-1, ch).mean(axis=1)
k = 2 if sr == 44100 else 1
if k == 2:
    a = np.convolve(a, [0.25, 0.5, 0.25], mode="same")[::2]
out = wave.open(dst, "wb"); out.setnchannels(1); out.setsampwidth(2); out.setframerate(sr // k)
out.writeframes((np.clip(a, -1, 1) * 32767 * 0.9).astype(np.int16).tobytes()); out.close()
print(dst, "%.1fs" % (len(a) / (sr // k)), "from", ch, "ch", sw * 8, "bit", sr)
