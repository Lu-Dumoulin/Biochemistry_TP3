# Kymographs of dynamic microtubules (M. Andreu-Carbó, 2020)

**Author of the data:** Mireia Andreu-Carbó, Department of Biochemistry, University of Geneva.
The movies were recorded on 23 July 2020 as a test and shared for this course.

**Licence:** [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). You may reuse and adapt these
images, provided you credit the author, for example:

> Kymographs: Mireia Andreu-Carbó, University of Geneva (2020), CC BY 4.0.

## Experiment

Microtubules grown in vitro from stabilized seeds, with 6 µM tubulin and 100 mM KCl, without
kinesin. Fluorescence microscopy, one image every 3 s for about 14 min,
0.11 µm per pixel. Three fields of view: movie A (0.5 µl of seeds) and movies B and C (1 µl of
seeds, two positions). The tubulin channel was used.

## Files

* `*_lineNNN.png` — one kymograph per isolated microtubule: time runs down (one row per frame),
  position runs to the right (one column per pixel along the microtubule), the seed is on the left.
* `kymographs.csv` — for each kymograph: its movie, the line in the movie (row and column of both
  ends, in pixels), the calibration (µm per pixel, s per frame), the condition, and `seed_col`, the
  column where the seed ends (the seed itself is not labeled in this channel).
* `*_overview.png` — the maximum projection of each movie, with the numbered lines.
* `reference_traces.csv` — corners of the growing edge of 37 kymographs, from automatic edge
  detection checked by eye (the other 9 are left for manual tracing).

The kymographs were extracted automatically by `src/Movies.jl` (lines detected on the maximum
projection, 3-pixel-wide intensity profiles, isolated microtubules only), then selected by eye:
46 of 98 were kept.
