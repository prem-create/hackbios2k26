"""Plug-in point for the photo-realistic (diffusion) try-on, e.g. CatVTON / IDM-VTON.
Needs a GPU. Implement run() and set TRYON_HQ=1. Left as a stub on purpose: model choice,
weights and licences depend on where you deploy."""
def run(person_bgr, garment_bgr):
    raise NotImplementedError("Wire CatVTON/IDM-VTON here (see README).")
