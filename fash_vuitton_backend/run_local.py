"""Webcam demo (no Flutter): python run_local.py
Keys: 1 tee, 2 tank, 3 long sleeve, c color, p stripes, [ ] fit, q quit"""
import sys, cv2
sys.path.insert(0, "server")
from engine import TryOnSession
from garments import GarmentLibrary, COLORS

lib, sess = GarmentLibrary("garments"), TryOnSession()
style, ci, stripes, fit = "tee", 0, False, 1.0
cap = cv2.VideoCapture(0)
while cap.isOpened():
    ok, frame = cap.read()
    if not ok: break
    g = lib.resolve(f"proc:{style}:{COLORS[ci]}" + (":stripes" if stripes else ""))
    out, info = sess.process(frame, g, fit=fit, mirror=True)
    cv2.putText(out, f"{info['ms']} ms  3D fit: {info['reproj_px']} px", (10, 24), cv2.FONT_HERSHEY_SIMPLEX, .6, (255, 255, 255), 2)
    cv2.imshow("Try-on", out)
    k = cv2.waitKey(1) & 0xFF
    if k == ord("q"): break
    if k == ord("c"): ci = (ci + 1) % len(COLORS)
    if k == ord("p"): stripes = not stripes
    if k == ord("["): fit = max(.8, fit - .02)
    if k == ord("]"): fit = min(1.3, fit + .02)
    style = {ord("1"): "tee", ord("2"): "tank", ord("3"): "long"}.get(k, style)
cap.release(); sess.close()
