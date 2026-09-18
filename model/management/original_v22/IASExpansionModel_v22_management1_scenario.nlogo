extensions [ gis
  csv ]

globals [
  presence-map               ;; presence shapefile
  elevation-map              ;; raster 10m derived from 30m DEM
  road-map                   ;; vials shape
  river-map                  ;; river shape from Rediam
  urban-map                  ;; urban centers shape from Rediam
  dams-map                   ;; dams shape from Rediam
  topo-nuclei-map            ;; capa con los nombres de los núcleos
  resistancebio-map          ;; raster 10 m derived from SIPNA
  habitatsuit-map            ;; raster iSDM
  kernel-matrix              ;; matriz de dispersión
  active-mask                ;; raster with 1 km buffer from sampled road
  agri-layer                 ;; raster with agriculture zones (SIPNA SIOSE) --> Nota: para ver en terminal de comandos: ask patches with [agri-zone?] [set pcolor green + 1 ]
  start-year
  ;; --- parámetros ecológicos / de proceso ---
  maturity-age-years        ;; minimum age to allow sexual reproduction
  min-sup-for-reproduction  ;; minimal surface (m²) to allow reproduction
  sterile-years-cut         ;; years with zero reproduction after "cut"
  sterile-years-reveg       ;; years with zero reproduction after "cut+revegetation"
  gamma-recovery            ;; years for post-cut ramp to reach full effect (e.g., 3)
  dispersal_radius_m        ;; radio de dispersión en metros
  kernel_decay              ;; parámetro de decaimiento exponencial
  kernel_a                  ;; escala del kernel
  management_reset_size     ;; superfcie de rodal tras manejo
  ;; --- resistencia biótica ---
  a                         ;; mínimo del mapeo lineal de resistencia (penalización basal)
  b_minus_a                 ;; amplitud del mapeo: b = min(1, a + b_minus_a)
  r_weight_estab            ;; exponente (curvatura) en establecimiento
  r_weight_growth           ;; exponente (curvatura) en crecimiento
  ;; métricas 10 m
  obs_cells_by_year_10m     ;; observado
  sim_cells_by_year_10m     ;; simulación

  patch-w-m
  patch-h-m
  patch-area-m2
  kernel-offsets            ;; list of [offx offy prob]
  kernel-cumprobs           ;; cumulative probs for fast sampling
  max-dispersal-attempts    ;; cap for speed

  ;; Update
  cut-sampling              ;; buffer where the sampling has been implemented from 2008 to 2023 (10m from the road)
  cut-management            ;; area to manage at each scenario
]


;; Agent properties (agent state variables)
turtles-own [
  species               ;; species identity (IAS) --> Solo trabajamos con A. altissima, pero dejamos por escalabilidad
  age                   ;; adequate age for reproduction (years), based on height
  sup-inicial           ;; superficie de entrada al sistema
  sup-actual            ;; superficie dinámica (se va actualizando)
  sup-teorica           ;; superficie esperada según la curva
  managed?              ;; to avoid repeated treatment
  last-managed-tick     ;; last tick in which management was applied
  management-count      ;; number of times the rodal has been treated
  last-management-type  ;; "cut", "cut+revegetation", or "none"
]


;; Patches definition (patches state variables)
patches-own [
  active?             ;; true if within 1 km buffer
  occupied?           ;; presence of IAS agent (boolean, for initialization purposes)
  elevation           ;; altitude in metres (m)
  habitat-suitability ;; Probability of occurrence or invasibility for the IAS
  resistance-bio      ;; biotic resistance index based on habitat class
  agri-zone?          ;; agriculture zones (value = 1)
  management-zone?    ;; patch selected for management
  revegetated?        ;; patch revegetated
  in-survey?          ;; for calibration (TRUE si el patch está en la franja 10 m)
  survey10            ;; for calibration (valor numérico aplicado desde el raster (0/1))
  ever-occupied?      ;; for calibration (acumulado "alguna vez ocupado")

  inside-management?             ;; inside the management area
]

to startup
  ; Load and render elevation as background
  load-elevation-map
  gis:set-world-envelope-ds gis:envelope-of elevation-map
  set-patch-metrics
  initialize-elevation
  color-by-elevation

  ; Load topological nuclei layer
  set topo-nuclei-map gis:load-dataset "abm_prep/topo_nucleos.shp"
  draw-nucleus-names

  ; Optional message to orient the user
  user-message "Choose visuals and press SETUP to begin the simulation."
end


to setup
  clear-all
  ask patches [ set occupied? false ]
  ask patches [ set management-zone? false ]
  ask patches [ set revegetated? false ]
  load-presence-map
  load-elevation-map
  gis:set-world-envelope-ds gis:envelope-of elevation-map  ;; define el marco para NetLogo
  set-patch-metrics
  initialize-elevation           ;; charges the elevation map in the visual interface
  color-by-elevation             ;; colour range for the elevation map visualized

  ;; --- máscara y observación para calibración ---
  set obs_cells_by_year_10m [75 75 76 76 78 78 80 80 80 80 80 80 80 80 80 87]

  ;; --- capas auxiliares / dibujo ---
  set agri-layer gis:load-dataset "abm_prep/agriculture_control.asc"
  initialize-agriculture-zones
  set road-map gis:load-dataset "abm_prep/roads.shp"
  set river-map gis:load-dataset "abm_prep/rivers.shp"
  set urban-map gis:load-dataset "abm_prep/urban_areas.shp"
;  draw-reference-layers
  set topo-nuclei-map gis:load-dataset "abm_prep/topo_nucleos.shp"
;  draw-nucleus-names

  ;; --- presencias iniciales ---
  mark-presence-from-polygons    ;; coloured in red patches with the IAS
  create-IAS-from-polygons       ;; centroid based
;  plot-size-distribution         ;; histogram of the distribution of the IAS'size (based on surface)


  ;; --- resistencia, máscara activa, idoneidad ---
  set resistancebio-map gis:load-dataset "abm_prep/resistance_0_1_def.asc"
  initialize-resistance-bio
  set active-mask gis:load-dataset "abm_prep/area_activa_binaria.asc"
  initialize-active-mask
  set habitatsuit-map gis:load-dataset "abm_prep/Ailanthus_ABM10m_probs.asc"
  initialize-habitat-suitability

  set-scenario-params-3B-best
  build-kernel-matrix
  build-kernel-sampler

  update-rodal-size
  set start-year 2008

  ;; add the management area
  set cut-management gis:load-dataset "C:/Users/claud/Downloads/UCO_contrato/Proyecto/02_ABM_Capitulo2/02_ABM_Capitulo2/abm_prep/recorte_100m.shp"
  ask patches [
    set inside-management? gis:intersects? cut-management self ;; property of patches, recognize if they intersect with the road buffer
    if inside-management? [ set pcolor gray ]   ;; only to see road buffer
  ]

  ;; Go with management:
  set management-enabled? true
  set management-type "cut"
  set management-frequency "once"
  set management-start-tick 17 ;; Start management by year 2025

  reset-ticks

end

;; Update
to update-occupied-patches

  ;; DISPERSAL IS MANDATORY
  ;;
  ;; Each turtle occupies only its current patch (alternative scenario to limit population expansion, and thus, according to cell resistance when establishing)
  ;; the logics behind this is that population expansion is possible through dispersal and establishment. Thus, a given agent cannot colonize new patches
  ;; without dispersing (dispersal - expansion are mandatory)
  ask turtles [
    ask patch-here [
      set occupied? true
      set pcolor green
      ]
  ]

end

; ----------------------------------------------------------------
; ------------ Initialization proceedings ------------------------

to set-scenario-params-3B-best
  ;; Best 3B
  set dispersal_radius_m       350
  set kernel_decay             0.00362698
  set maturity-age-years       4
  set min-sup-for-reproduction 61.9332
  set a                        0.779919
  set b_minus_a                0.541924
  set r_weight_estab           0.889097
  set r_weight_growth          4.79542
  set management_reset_size    11.9674
  set gamma-recovery           1.93439

  ;; Fijos
  set sterile-years-cut        0
  set sterile-years-reveg      4
  set kernel_a                 2.08
  set max-dispersal-attempts   10
end

to load-presence-map
  set presence-map gis:load-dataset "abm_prep/ailanthus_all.shp"
  gis:set-world-envelope-ds gis:envelope-of presence-map
end

to load-elevation-map
  set elevation-map gis:load-dataset "abm_prep/altitud_abm_10m.asc"
  gis:set-world-envelope-ds gis:envelope-of elevation-map
end

to initialize-elevation
  ask patches [
    let z gis:raster-sample elevation-map self
    if is-number? z [
      set elevation z
    ]
  ]
end

to color-by-elevation
  ask patches [
    set pcolor scale-color brown elevation 200 2000
  ]
end

to draw-reference-layers
  if show-roads? [
    gis:set-drawing-color gray
    gis:draw road-map 1.0
  ]
  if show-rivers? [
    gis:set-drawing-color blue
    gis:draw river-map 1.0
  ]
  if show-urban? [
    gis:set-drawing-color red + 2
    gis:draw urban-map 1.5
  ]
end

to draw-nucleus-names
  let features gis:feature-list-of topo-nuclei-map
  foreach features [ f ->
    let loc gis:location-of (gis:centroid-of f)
    let name gis:property-value f "TextString"
    if loc != nobody and is-string? name [
      let x item 0 loc
      let y item 1 loc
      ask patch x y [
        set plabel name
        set plabel-color white
      ]
    ]
  ]
end


to mark-presence-from-polygons
  let feature-list gis:feature-list-of presence-map
  foreach feature-list [ f ->
    ask patches [
      if gis:intersects? f self [
        set occupied? true
        set pcolor red  ; colorear el patch ocupado
      ]
    ]
  ]
end

to-report estimate-age [hc sup]
  if not is-number? hc [ report 3 ]  ;; valor por defecto
  if hc = 1 [ report 1 + random 2 ]      ;; 0–2 años
  if hc = 2 [ report 3 + random 3 ]      ;; 3–5 años
  if hc = 3 [ report 6 + random 4 ]      ;; 6–10 años
  if hc = 4 [
    ifelse is-number? sup [
      if sup > 400 [ report 15 + random 5 ] ;; si tiene más de 400 m², asumir que es >15 años
      report 11 + random 4
    ] [
      report 10
    ]
  ]
  report 5
end

to set-patch-metrics
  ;; Uses the GIS envelope currently mapped to the NetLogo world
  let env gis:world-envelope
  set patch-w-m ((item 1 env - item 0 env) / world-width)
  set patch-h-m ((item 3 env - item 2 env) / world-height)
  set patch-area-m2 (patch-w-m * patch-h-m)


;show (word "Patch size (m): " precision patch-w-m 2 " x " precision patch-h-m 2
;           " ; area(m2)=" precision patch-area-m2 1)

end


; ----------------------------------------------------------------
; Logistic growth curve for Ailanthus stands
; Units:
;   - edad (input): years
;   - output: stand surface area (m²)
; Parameters (fixed, empirical fit from GSV/field data):
;   K = 401.7 m² (carrying surface)
;   θ = 4.2 (inflection point, years)
;   β = 1.06 (steepness)
; Reference: Kowarik & Säumel (2007); empirical fit (2008–2023 GSV data)
; Used in:
;   - growth-phase (annual increment)
;   - initialization of sup-teorica
; ----------------------------------------------------------------
to-report logistic-surface [edad]
  report 401.7 / (1 + exp ((4.2 - edad) / 1.06))
end


to create-IAS-from-polygons
  let feature-list gis:feature-list-of presence-map
  foreach feature-list [ f ->
    let yr gis:property-value f "Year"
    if yr = 2008 [
      let pt gis:location-of (gis:centroid-of f)
      if pt != nobody [
        let x item 0 pt
        let y item 1 pt

        ;; Atributos del feature
        let height-cat gis:property-value f "Height_cat"
        let dens gis:property-value f "Sp_dens_m2"

        ;; Estimación de edad basada en height_cat y dens (superficie calculada – BD)
        let estimated-age estimate-age height-cat dens

        ;; Superficie inicial y cálculo teórico según edad
        let sup-inicial-value (ifelse-value is-number? dens [dens] [10]) ;; valor mínimo si nulo
        let sup-teo-value logistic-surface estimated-age

        create-turtles 1 [
          setxy x y
          set species "Ailanthus altissima"
          set color lime - 1
          set shape "tree"

          set age estimated-age
          set sup-inicial sup-inicial-value
          set sup-actual sup-inicial-value
          set sup-teorica sup-teo-value
          set managed? false
          set last-managed-tick -1
          set management-count 0
          set last-management-type "none"
        ]
      ]
    ]
  ]
end


to update-rodal-size
  ;; Parámetros de visualización
  let min-size 0.5  ;; tamaño mínimo visual
  let max-size 5    ;; tamaño máximo visual
  let epsilon 0.01  ;; tolerancia para evitar actualizaciones innecesarias

  ask turtles [
    let scaled-size sup-actual / 100
    let target-size max list min-size (min list scaled-size max-size)

    ;; Solo actualizamos si hay diferencia significativa
    if abs (size - target-size) > epsilon [
      ;; Pero evitamos que el tamaño disminuya visualmente
      if target-size > size [
        set size target-size
      ]
    ]
  ]
end


to plot-size-distribution
  clear-plot
  histogram [size] of turtles
end


to initialize-resistance-bio
  ask patches [
    let val gis:raster-sample resistancebio-map self
    ifelse is-number? val [
      set resistance-bio val
    ] [
      set resistance-bio 0  ; sin datos → sin resistencia
    ]
  ]
end


to initialize-agriculture-zones
  ask patches [
    let val gis:raster-sample agri-layer self
    ifelse is-number? val and val = 1 [
      set agri-zone? true
    ] [
      set agri-zone? false
    ]
  ]
end


to initialize-active-mask
  ask patches [
    let val gis:raster-sample active-mask self
    ifelse is-number? val [
      set active? (val = 1)  ;; transforma 1 en true y 0 en false
    ] [
      set active? false
    ]
  ]
end


to initialize-habitat-suitability
  ask patches [
    let val gis:raster-sample habitatsuit-map self
    ifelse is-number? val [
      set habitat-suitability val
    ] [
      set habitat-suitability 0 ;; o un valor por defecto si no hay datos
    ]
  ]
end

to build-kernel-matrix
  ;; Build a square matrix in PATCH OFFSETS, but compute distance in METERS
  ;; using the true patch width/height derived from the GIS envelope.

  ;; Safety: if metrics not set, compute them
  if patch-w-m = 0 or patch-h-m = 0 [ set-patch-metrics ]

  ;; How many patch steps are needed to cover the dispersal radius in both axes?
  let max-dx ceiling (dispersal_radius_m / patch-w-m)
  let max-dy ceiling (dispersal_radius_m / patch-h-m)

  ;; Keep it square to remain compatible with disperse-offspring (which assumes kdim x kdim)
  let half max list max-dx max-dy
  let kdim (2 * half + 1)

  let result []
  foreach n-values kdim [i -> i] [
    i ->
    let row []
    foreach n-values kdim [j -> j] [
      j ->
      let offx (j - half)
      let offy (i - half)

      ;; distance in meters for a rectangular (anisotropic) grid
      let dist sqrt ((offx * patch-w-m) ^ 2 + (offy * patch-h-m) ^ 2)

      ;; truncate beyond the target radius
      let val 0
      if dist <= dispersal_radius_m [
        set val kernel_a * exp (-(kernel_decay * dist))
      ]
      set row lput val row
    ]
    set result lput row result
  ]

  ;; normalize to sum 1 (guard against total=0)
  let total sum map [row -> sum row] result
  if total <= 0 [
    ;; fallback: no dispersal (all zeros) — but normally radius>0 prevents this
    set kernel-matrix result
    stop
  ]
  set kernel-matrix map [row -> map [x -> x / total] row] result
end

to build-kernel-sampler
  set kernel-offsets []
  set kernel-cumprobs []

  let kdim length kernel-matrix
  let half floor (kdim / 2)

  ;; build offsets excluding the center cell (0,0)
  let total 0
  foreach n-values kdim [i -> i] [ i ->
    let row item i kernel-matrix
    foreach n-values kdim [j -> j] [ j ->
      let offx (j - half)
      let offy (i - half)
      if not (offx = 0 and offy = 0) [
        let p item j row
        if p > 0 [
          set kernel-offsets lput (list offx offy p) kernel-offsets
          set total (total + p)
        ]
      ]
    ]
  ]

  ;; renormalize excluding center (defensive)
  if total > 0 [
    set kernel-offsets map [t -> (list (item 0 t) (item 1 t) ((item 2 t) / total))] kernel-offsets
  ]

  ;; cumulative distribution for roulette-wheel sampling
  let cum 0
  foreach kernel-offsets [t ->
    set cum (cum + item 2 t)
    set kernel-cumprobs lput cum kernel-cumprobs
  ]
end

to-report draw-kernel-offset
  let r random-float 1.0
  let idx 0
  ;; linear scan is OK because the kernel list is small; keep it simple
  while [idx < length kernel-cumprobs and r > item idx kernel-cumprobs] [
    set idx (idx + 1)
  ]
  if idx >= length kernel-offsets [ report (list 0 0) ]
  report (list (item 0 item idx kernel-offsets) (item 1 item idx kernel-offsets))
end


; ----------------------------------------------------------------
; -------------------- Behavior of IAS ---------------------------

; ----------------------------------------------------------------
; Annual clonal growth of Ailanthus stands
; Process:
;   - Increment stand age (+1 year)
;   - Compute logistic theoretical surface (m²) for age
;   - Calculate increment ΔS = (S_teo_age - S_teo_prev)
;   - Apply local resistance factor (1 - resistance-bio)
;   - Apply post-cut recovery ramp g(t)
; Units:
;   - age: years
;   - sup-actual: m²
;   - resistance-bio: 0..1 (dimensionless index from SIPNA-derived raster)
; Data layers used:
;   - resistance-bio (10 m, SIPNA)
; ----------------------------------------------------------------

to growth-phase
  ask turtles [
    if [active?] of patch-here [
      set age age + 1

      let sup-teo-anterior logistic-surface (age - 1)
      let sup-teo-actual logistic-surface age
      let incremento sup-teo-actual - sup-teo-anterior

      ; Obtener resistencia del patch
      let r-bio [resistance-bio] of patch-here
      if not is-number? r-bio [ set r-bio 0 ]  ;; seguridad

;      ;; post-cut ramp factor g(t)
;      let tsince (ifelse-value (last-managed-tick >= 0) [ticks - last-managed-tick] [1e9])
;      let cutlike? member? last-management-type ["cut" "cut+revegetation" "auto-agriculture"]
;      let g (ifelse-value (cutlike? and tsince < 1e8)
;                [ min (list 1 (tsince / gamma-recovery)) ]
;                [ 1 ])

      ;; post-cut ramp factor g(t)  (safe against gamma-recovery <= 0)
      let tsince (ifelse-value (last-managed-tick >= 0) [ticks - last-managed-tick] [1e9])
      let cutlike? member? last-management-type ["cut" "cut+revegetation" "auto-agriculture"]
      let gamma-safe max list 1e-6 gamma-recovery

      let g (ifelse-value (cutlike? and tsince < 1e8)
                [ min (list 1 (tsince / gamma-safe)) ]
                [ 1 ])


      ;let incremento-ajustado incremento * (1 - r-bio) * g
      let b min list 1 (a + b_minus_a)
      let incremento-ajustado incremento * (1 - (a + ((r-bio ^ r_weight_growth) * (b - a)))) * g
      ; evitar explícitamente que un rodal supere su valor teórico máximo para esa edad
      if sup-actual < sup-teo-actual [
        set sup-actual sup-actual + incremento-ajustado
      ]
      ;; keep the exported field in sync
      set sup-teorica sup-teo-actual
    ]
  ]
end


to reproduction-and-dispersal
  ask turtles [
    if reproductive-capacity > 0 [
      disperse-offspring
    ]
  ]
end


;; Dispersal
; ----------------------------------------------------------------
; Dispersal and establishment of Ailanthus offspring
; Purpose:
;   - Models the dispersal of propagules (samara seeds) from
;     parent stands and their potential establishment in nearby patches.
;
; Process (per stand, per tick):
;   1. Compute dispersal factor based on stand age
;      (dispersal-factor-by-age: ≤2y = 0.2, ≤5y = 0.6, ≤15y = 1.0, >15y = 0.5).
;   2. Loop over kernel-matrix (normalized exponential kernel):
;        - For each offset patch (i,j), probability = kernel value × dispersal factor.
;        - Candidate patches collected if random draw < probability.
;   3. Choose 1 patch at random from candidate set (n-of 1).
;   4. Establishment test: success if patch is unoccupied AND
;        random < habitat-suitability × (1 - resistance-bio).
;   5. If successful, create new turtle (stand) with:
;        - age = 0
;        - sup-inicial = sup-actual = 5 m² (default seedling size)
;        - sup-teorica = logistic-surface 0
;        - pcolor marked as red+1
;   6. Patch marked as occupied? = true.
;
; Units and parameters:
;   - age (years, tick-based)
;   - dispersal-factor (0..1, dimensionless multiplier)
;   - kernel-matrix: dimension ( (2*radius/res)+1 ), radius=250 m, res=10 m,
;     decay=0.04, a=2.08 (default, could be calibrated)
;   - habitat-suitability: [0..1], from iSDM raster (10 m resolution)
;   - resistance-bio: [0..1], from SIPNA-derived raster (10 m resolution)
;   - Initial offspring surface: 5 m² (fixed, calibratable)
;
; Data sources:
;   - Dispersal kernel parameters: Landenberger et al. (2007)
;     + calibration with GSV data.
;   - Habitat suitability: iSDM probabilities (ABM10m raster).
;   - Resistance: SIPNA-derived classes at 10 m.
; ----------------------------------------------------------------

to-report dispersal-factor-by-age [edad]
  if edad <= 2 [report 0.2]
  if edad <= 5 [report 0.6]
  if edad <= 15 [report 1.0]
  report 0.5
end


to disperse-offspring
  ;; age-based multiplier
  let df dispersal-factor-by-age age

  ;; reproductive capacity already includes maturity, size threshold, sterility, and recovery
  let rc reproductive-capacity
  if rc <= 0 [ stop ]

  ;; kernel_a used as dispersal INTENSITY (expected attempts),
  ;; not as a multiplier inside a normalized kernel
  let lambda (0.8 * rc * df * kernel_a)

  ;; choose number of attempts (cheap deterministic + cap)
  let n-attempts max list 1 round lambda
  if n-attempts > max-dispersal-attempts [ set n-attempts max-dispersal-attempts ]

  let x0 pxcor
  let y0 pycor

  repeat n-attempts [
    let off draw-kernel-offset
    let p patch (x0 + item 0 off) (y0 + item 1 off)

    if p != nobody and [active?] of p and (not [occupied?] of p) [
      ;; establishment
      let b min list 1 (a + b_minus_a)
      if random-float 1.0 < ([habitat-suitability] of p * (1 - (a + (([resistance-bio] of p) ^ r_weight_estab) * (b - a)))) [
        hatch 1 [
          move-to p
          set species "Ailanthus altissima"
          set color lime - 1
          set shape "tree"
          set age 0
          set sup-inicial 5
          set sup-actual 5
          set sup-teorica logistic-surface 0
          set pcolor red + 1
        ]
        ask p [ set occupied? true ]
        ;; optional: stop after first success this year (uncomment if desired)
        ;; stop
      ]
    ]
  ]
end



; ----------------------------------------------------------------
; Reproductive capacity of Ailanthus stands
; Purpose:
;   - Returns a multiplier [0..1] that represents the current
;     ability of a stand to produce propagules.
; Process (per stand, per tick):
;   1. Check sterile windows after management (cut, cut+reveg, auto-agriculture).
;   2. Apply maturity gate: reproduction allowed only if age ≥ maturity-age-years.
;   3. Apply structural gate: reproduction allowed only if sup-actual ≥ min-sup-for-reproduction.
;   4. Scale by vigor = sup-actual / sup-teorica (capped at 1).
;   5. Apply post-cut growth ramp g(t) = min(1, tsince / gamma-recovery)
;      to smooth recovery after management.
;
; Units and parameters:
;   - age (years, tick-based)
;   - sup-actual (m², dynamic stand surface)
;   - sup-teorica (m², logistic theoretical surface)
;   - maturity-age-years (int, years to reproductive maturity; default 3)
;   - min-sup-for-reproduction (m², default 6)
;   - sterile-years-cut (int, years with zero reproduction after cut; default 1)
;   - sterile-years-reveg (int, years with zero reproduction after cut+reveg; default 3)
;   - gamma-recovery (int, years to recover full vigor after management; e.g., 3)
; Data sources:
;   - Management parameters from experimental control strategies and calibration.
;   - Stand surfaces from GSV-derived polygons and field validation.
; ----------------------------------------------------------------

to-report reproductive-capacity
  ;; time since last management (large if never managed)
  let tsince (ifelse-value (last-managed-tick >= 0) [ticks - last-managed-tick] [1e9])

  ;; enforce sterile windows based on last treatment type
  if last-management-type = "cut" [
    if tsince < sterile-years-cut [ report 0 ]
  ]
  ;; treat auto-agriculture like CUT for sterile years
  if last-management-type = "auto-agriculture" [
    if tsince < sterile-years-cut [ report 0 ]
  ]
  if last-management-type = "cut+revegetation" [
    if tsince < sterile-years-reveg [ report 0 ]
  ]

  ;; maturity & structural gates
  if age < maturity-age-years       [ report 0 ]
  if sup-actual < min-sup-for-reproduction [ report 0 ]

  ;; vigor scaling: newly cut stands recover dispersal gradually with structure
  let denom max list 1 sup-teorica   ;; safe guard (evita divisiones entre cero)
  let vigor sup-actual / denom       ;; qué proporción de la sup máxima alcanzable ha recuperado el rodal
  if vigor > 1 [ set vigor 1 ]       ;; clamp to [0,1]

  ;; post-cut ramp factor g(t) for reproduction
  let cutlike? member? last-management-type ["cut" "cut+revegetation" "auto-agriculture"]
  let gamma-safe max list 1e-6 gamma-recovery
  let g (ifelse-value (cutlike? and tsince < 1e8)
            [ min (list 1 (tsince / gamma-safe)) ]
            [ 1 ])

  report vigor * g
end


to update-visibility
  ;; Control de visualización de parches ocupados
  ifelse show-occupied-patches? [
    ask patches with [occupied?] [ set pcolor red ]
  ] [
    ask patches with [occupied?] [
      if is-number? elevation [
        set pcolor scale-color brown elevation 200 2000
      ]
    ]
  ]

  ;; Control de visualización de rodales (turtles)
  ifelse show-rods? [
    ask turtles [ set hidden? false ]
  ] [
    ask turtles [ set hidden? true ]
  ]

end


; ----------------------------------------------------------------
; --------------- Management implementation ----------------------

to draw-management-zone
   ;; Do not manage before the management-start-tick
  if ticks < management-start-tick [ stop ]

  ;; ADDENDA to manage patches located in the road buffer
  ask patches [
    if inside-management? [ set management-zone? true] ;; Manage patches in the road
  ]
end


to select-rectangle
  user-message "Click first corner of the rectangle"
  while [not mouse-down?] [ ]
  let x1 mouse-xcor
  let y1 mouse-ycor
  wait 0.2

  user-message "Now click the opposite corner"
  while [not mouse-down?] [ ]
  let x2 mouse-xcor
  let y2 mouse-ycor
  wait 0.2

  let x-min min (list x1 x2)
  let x-max max (list x1 x2)
  let y-min min (list y1 y2)
  let y-max max (list y1 y2)

  ask patches with [
    pxcor >= x-min and pxcor <= x-max and
    pycor >= y-min and pycor <= y-max
  ] [
    set management-zone? true
    set pcolor cyan
  ]
end


to clear-management-zone
  ask patches with [management-zone?] [
    set management-zone? false
    if is-number? elevation [
      set pcolor scale-color brown elevation 200 2000
    ]
  ]
end


; ----------------------------------------------------------------
; Management submodel: apply-management
; Purpose:
;   - Implements user-scheduled management interventions on stands,
;     differentiating between "cut" and "cut+revegetation".
;   - Updates stand state variables and patch attributes accordingly.
;
; Process (per selected patch / management zone):
;   1. Identify turtles (stands) on the target patch.
;   2. Reset sup-actual (surface) to small baseline (5 m²).
;   3. Update management memory:
;        - last-managed-tick = current ticks
;        - last-management-type = "cut" or "cut+revegetation"
;        - management-count += 1
;   4. If "cut+revegetation":
;        - Increase patch resistance-bio by +0.2 (capped at 1.0).
;        - Set patch flag revegetated? = true.
;   5. Visual update: recolor patches / turtles to indicate treatment.
;
; Units and parameters:
;   - sup-actual: m² (reset to 5 m² after treatment)
;   - sterile-years-cut: years of zero reproduction after cut
;   - sterile-years-reveg: years of zero reproduction after cut+reveg
;   - resistance-bio increment: +0.2 (dimensionless, capped at 1.0)
;   - age (years): NOT reset, stands retain their age (ecologically realistic)
;   - last-managed-tick: tick index when treatment occurred
;   - management-count: integer (how many times a stand has been treated)
;   - last-management-type: categorical (none | cut | cut+revegetation | auto-agriculture)
;
; Data sources:
;   - Management regimes defined by user or experimental setup.
;   - Resistance increment after revegetation inspired by restoration practices
;     where native planting increases community resistance to invasion.
;
; Notes:
;   - Age is not reset: this avoids unrealistic "juvenilization" after cutting.
;   - Interaction with other submodels:
;        * growth-phase → continues from current age but with reduced sup-actual
;        * reproductive-capacity → silenced during sterile window + ramp recovery
;   - Auto-agriculture is not here; it is applied automatically in agri-zone patches
;     within `go`, but follows the same logic (reset to 5 m² + management memory).
; ----------------------------------------------------------------

to apply-management
  ;; Increase biotic resistance in revegetated areas (capped at 1.0)
  if management-type = "cut+revegetation" [
    ask patches with [management-zone? and not agri-zone?] [
      set resistance-bio min (list (resistance-bio + 0.2) 1.0)
      set revegetated? true
    ]
  ]

  ; If erradication is implemented, eliminate A. altissima and apply revegetation
  if management-type = "erradication" [
    ask patches with [management-zone? and not agri-zone?] [
      set resistance-bio min (list (resistance-bio + 0.2) 1.0)
      set revegetated? true
      set occupied? false
    ]
  ]

  ;; Apply treatment to the stands (turtles) in management zones
  ;; If frequency is "once", avoid retratment of previously managed stands
  ask turtles with [
    [management-zone?] of patch-here and
    not [agri-zone?] of patch-here and
    (management-frequency != "once" or not managed?)
  ] [

    ;; print to console for debugging
    print (word "Management applied to stand " self " at tick " ticks)

    ;; Apply CUT only (stimulates vegetative regrowth)
    if management-type = "cut" [
;      set sup-actual 5  ;; reset surface, proxy of biomass/height
      set sup-actual management_reset_size
      set sup-teorica logistic-surface age
      set color orange
    ]

    ;; Apply CUT + REVEGETATION (cut + resistance increase)
    if management-type = "cut+revegetation" [
;      set sup-actual 5
      set sup-actual management_reset_size
      set sup-teorica logistic-surface age
      set color blue
    ]

    if management-type = "erradication" [
      set sup-actual 0
      set sup-teorica 0
      set color blue
      die ;; Important! Target plant is completely erradicated under this treatment
    ]

    ;; Track management history
    set last-managed-tick ticks
    set management-count management-count + 1
    set last-management-type management-type
    set managed? true

  ]

  if management-frequency = "once" [
  ask patches with [management-zone?] [
    set management-zone? false
    if is-number? elevation [
      set pcolor scale-color brown elevation 200 2000
    ]
  ]
]
end

;; export all data
to export-management-summary
  export-world "rodales_managed.csv"
end

;; export just key stand info
to export-management-tables
  ;; Open output file (overwrite if exists) !NOTE:Is not working propoerly, bettter to rename or deleted previous one if exists
  file-open "rodales_summary.csv"

  ;; Write header
  file-print "who,xcor,ycor,age,sup-actual,sup-teorica,last-managed-tick,management-count,last-management-type"

  ;; Write one row per rodal (turtle)
  ask turtles [
    file-print (word
      who "," xcor "," ycor "," age "," sup-actual "," sup-teorica ","
      last-managed-tick "," management-count "," last-management-type)
  ]

  file-close
end



; -----------------------------------------------------------------
; ------------------------ TO GO ----------------------------------

to go

  update-rodal-size
  update-visibility
  ;; plots
  if ticks mod 1 = 0 [
    let total-surface sum [sup-actual] of turtles
    set-current-plot "Occupied surface over time"
    set-current-plot-pen "total"
    plotxy (start-year + ticks) total-surface
  ]
  display


  growth-phase

    ; Apply automatic control in agricultural areas
  ask turtles with [ [agri-zone?] of patch-here ] [
;    set sup-actual 5
    set sup-actual management_reset_size
    set color yellow
    set last-managed-tick ticks
    set last-management-type "auto-agriculture"
    set management-count management-count + 1
    set managed? true
    set sup-teorica logistic-surface age
  ]

  ;; Management by type and frecuency

    if management-enabled? [
    draw-management-zone

    let should-apply-management? false

    if management-frequency = "once" and ticks = management-start-tick [
      set should-apply-management? true
    ]
    if management-frequency = "annual" and ticks >= management-start-tick [
      set should-apply-management? true
    ]
    if management-frequency = "biennial" and ticks >= management-start-tick and ticks mod 2 = 0 [
      set should-apply-management? true
    ]
    if management-frequency = "quadrennial" and ticks >= management-start-tick and ticks mod 4 = 0 [
      set should-apply-management? true
    ]

    if should-apply-management? [
      apply-management
      update-rodal-size
    ]

  ]

  reproduction-and-dispersal
  update-rodal-size
  update-visibility

  ;; Update
  update-occupied-patches

  ;; Plot surface over time
  if ticks mod 1 = 0 [  ;; cambiar a 5, 10, etc., para trazar solo cada X años
  let total-surface sum [sup-actual] of turtles
  set-current-plot "Occupied surface over time"
  set-current-plot-pen "total"
  plotxy (start-year + ticks) total-surface
 ]




  tick

  ;; Update
  if ticks = 27 or ticks = 37 [
    export-asc] ;; Export at years 2035 and 2045

  display  ;; display all the changes made during this tick
  if ticks >= 37 [ stop ]

end


;; Update
;; Export a raster with the occupied patches within the road buffer
to export-asc
  let xmin min [pxcor] of patches
  let xmax max [pxcor] of patches
  let ymin min [pycor] of patches
  let ymax max [pycor] of patches

  let ncols 2423
  let nrows 1372
  let cellsize 10
  let xllcorner 444408.274179058382
  let yllcorner 4077082.299595065415

  file-open (word "output_binary" behaviorspace-run-number "_tick" ticks ".asc")
  file-print (word "ncols " ncols)
  file-print (word "nrows " nrows)
  file-print (word "xllcorner " xllcorner)
  file-print (word "yllcorner " yllcorner)
  file-print (word "cellsize " cellsize)
  file-print "NODATA_value -9999"

  let row 0
  while [row < nrows] [
    let y yllcorner + (nrows - 1 - row) * cellsize
    let line ""
    let col 0

    while [col < ncols] [
      let x xllcorner + col * cellsize
      let px round ( xmin + (x - xllcorner) / cellsize * (xmax - xmin) / (ncols - 1) )
      let py round ( ymin + (y - yllcorner) / cellsize * (ymax - ymin) / (nrows - 1) )
      let p patch px py

      let val 0
      if p != nobody [
        if [occupied?] of p [
          set val 1
        ]
      ]
      set line (word line val " ")
      set col col + 1
    ]

    file-print line
    set row row + 1
  ]

  file-close
  user-message "Binary raster exported: output_binary.asc"
end
@#$#@#$#@
GRAPHICS-WINDOW
228
71
1466
563
-1
-1
3.0
1
10
1
1
1
0
0
0
1
0
409
0
160
0
0
1
years
5.0

BUTTON
45
231
173
264
Setup model
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1529
247
1637
280
Run one year
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
228
574
912
732
Occupied surface over time
Time (Year)
Surface (m²)
2008.0
2038.0
0.0
1000000.0
false
false
"" ""
PENS
"total" 1.0 0 -14439633 true "" ""

TEXTBOX
402
28
1305
56
DINÁMICA DE EXPANSIÓN DE AILANTHUS ALTISSIMA ANTE DIFERENTES ESCENARIOS DE GESTIÓN
20
0.0
1

TEXTBOX
1488
454
1638
479
333 km2\n66 km sample roads
11
0.0
1

SWITCH
1490
124
1667
157
show-occupied-patches?
show-occupied-patches?
1
1
-1000

MONITOR
928
582
1059
627
Núm.total rodales
count turtles
17
1
11

MONITOR
928
631
1052
676
Tamaño medio rodal
mean [size] of turtles * 100
2
1
11

MONITOR
1056
631
1144
676
Tamaño máx.
max [size] of turtles * 100
2
1
11

MONITOR
1149
631
1214
676
Mediana
median [size] of turtles * 100
2
1
11

MONITOR
1066
581
1214
626
Nuevos rodales (año actual)
count turtles with [age = 0]
17
1
11

MONITOR
930
683
1213
728
Núm. de parches ocupados
count patches with [occupied? and active?]
17
1
11

SWITCH
1491
162
1668
195
show-rods?
show-rods?
0
1
-1000

SWITCH
23
339
200
372
management-enabled?
management-enabled?
1
1
-1000

TEXTBOX
27
321
177
339
Enable management?
11
0.0
1

CHOOSER
21
398
200
443
management-type
management-type
"none" "cut" "cut+revegetation" "erradication"
2

TEXTBOX
24
381
174
399
Management type
11
0.0
1

CHOOSER
22
469
199
514
management-frequency
management-frequency
"once" "annual" "biennial" "quadrennial"
0

TEXTBOX
24
450
174
468
Frequency
11
0.0
1

TEXTBOX
23
521
173
539
Start tick (year)
11
0.0
1

SWITCH
22
622
199
655
draw-zone?
draw-zone?
0
1
-1000

BUTTON
22
663
100
696
Draw zone
draw-management-zone\n
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
23
603
173
621
Drawing options
11
0.0
1

BUTTON
62
706
149
740
Clear zone
clear-management-zone
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1371
506
1456
551
Current Year
start-year + ticks
0
1
11

BUTTON
107
663
195
696
Select rectangle
select-rectangle
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
47
112
173
145
show-roads?
show-roads?
1
1
-1000

SWITCH
46
150
172
183
show-rivers?
show-rivers?
1
1
-1000

SWITCH
45
186
172
219
show-urban?
show-urban?
1
1
-1000

TEXTBOX
27
66
206
108
-------------------------------------------\n            1. SETUP MODEL\n-------------------------------------------
11
0.0
1

TEXTBOX
25
273
216
312
-------------------------------------------\n        2. MANAGEMENT SETTINGS\n-------------------------------------------
11
0.0
1

TEXTBOX
1496
64
1783
134
-------------------------------------------\n     3. RUNNING THE SIMULATION\n-------------------------------------------
11
0.0
1

TEXTBOX
1498
103
1648
121
Vizualization (applied next tick)
11
0.0
1

BUTTON
1527
208
1636
241
Run simulation
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
1495
300
1675
370
-------------------------------------------\n      4. EXPORT RESULTS (.csv)\n-------------------------------------------
11
0.0
1

BUTTON
1528
351
1630
384
Export world
export-management-summary
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1492
394
1688
427
Export management summary
export-management-tables
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
1487
489
1671
769
======================\n                 Quick start:\n1. Click Setup model to load data.\n2.(Optional) Toggle visual layers (stands, patches).\n3. Enable management if you want to test control actions.\n4. Choose management type, frequency, and start year.\n5. Draw treatment zones (use Draw zone or Select rectangle).\n6. Click Run simulation to start, or Run one year to advance step-by-step.\n7. Observe maps and charts; export results if needed.\n======================\n
11
2.0
1

TEXTBOX
1248
603
1501
621
🟩 Stands (initial)
11
66.0
1

TEXTBOX
1248
618
1440
636
🟩 Stands (managed by farmers)
11
44.0
1

TEXTBOX
1249
634
1424
653
🟩 Stands (managed by cutting)
11
25.0
1

TEXTBOX
1249
647
1464
665
🟩 Stands (managed by cut + revegetation)
11
105.0
1

TEXTBOX
1249
661
1399
679
🟫 Occupied patches
11
15.0
1

TEXTBOX
1249
675
1399
693
⬜ Roads
11
5.0
1

TEXTBOX
1249
687
1399
705
⬜ Urban settings
11
17.0
1

TEXTBOX
1249
701
1399
719
🟦 Rivers
11
104.0
1

TEXTBOX
1249
715
1399
733
🟫 Management zones
11
85.0
1

TEXTBOX
1248
580
1398
598
Legend:\n
11
0.0
1

TEXTBOX
23
535
192
579
tick = 0  → año 2008; tick = 15 → año 2023; tick = 22 → año 2030; etc.
9
1.0
1

SLIDER
22
563
199
596
management-start-tick
management-start-tick
0
30
1.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

This is an agent-based model (ABM) designed to simulate the expansion of *Ailanthus altissima* (tree-of-heaven), a highly invasive tree species, along Mediterranean road corridors. The model represents stands (rodales) as agents that grow clonally, reproduce, disperse propagules, and respond to different management actions such as cutting or cutting combined with revegetation.

The purpose of the model is twofold:

1. To replicate the observed dynamics of *A. altissima* from 2008 to 2023 along the Capileira–Guájares road corridor (Granada, Spain), using data from field surveys and Google Street View.

2. To explore alternative management scenarios, assessing how different strategies (frequency, intensity, type of treatment) may influence the invasion trajectory and support decision-making for land managers.

By integrating empirical growth functions, dispersal kernels, and habitat suitability maps, the model provides a spatially explicit, process-based tool to understand the drivers of A. altissima spread and to test management interventions under realistic landscape conditions.


## HOW IT WORKS

The agents in the model represent vegetative stands of *Ailanthus altissima*. Each agent corresponds to a stand rather than an individual plant, which provides a realistic ecological abstraction for simulating the species’ clonal growth, dispersal, and response to management. Native vegetation is not explicitly represented as agents. Instead, resistance to invasion is encoded as patch-level indices (biotic from SIPNA/SIOSE classes and land-use filters, e.g. agricultural zones), which directly modulate the success of invasive stands in growth, reproduction, and establishment.

The environment is implemented as a raster grid of 10 × 10 m patches, with only those cells located within a 1 km buffer of the Capileira–Guájares road corridor defined as active. Each patch is attributed with environmental and resistance values derived from GIS datasets: elevation (from a DEM), a biotic resistance index (from SIPNA/SIOSE), agricultural zones, and habitat suitability probabilities obtained from an invasive species distribution model (iSDM). Additional reference layers (roads, rivers, and urban nuclei) are included for visualization and potential future analysis. 

Initialization proceeds by loading presence polygons dated to 2008. For each polygon, the model identifies intersecting patches and sets their state variable occupied? = true. One agent is created per polygon and located at its centroid. Agents are initialized with ecological traits derived from shapefile attributes:

• Age at initialization is inferred from Height_cat as a proxy for ontogenetic stage, not as exact chronological age;
• Initial surface (sup-inicial), taken as the observed coverage (or set to a default if missing);
• Dynamic surface (sup-actual), updated annually via a logistic growth function;
• Theoretical surface (sup-teorica), calculated from age using a fitted logistic curve;
• Management history, with fields tracking previous treatments and their effects.

Each annual tick represents one year and includes the following processes:

1. Clonal growth: stand surface increases according to the logistic growth curve, adjusted by the patch-level resistance index.
2. Management (optional): scenarios allow stand removal by cutting or cutting combined with revegetation. These treatments reduce stand surface, enforce sterile periods (differentiated by treatment type), and in the case of revegetation, increase local resistance values. Automatic control is applied in agricultural zones every year, resetting stands to a small baseline size, functionally equivalent to a cut treatment.
3. Reproduction and dispersal: agents exceeding age and surface thresholds, and not under sterile conditions from prior management, may reproduce with probability determined by reproductive capacity (age, size, sterile periods, vigor scaling, and post-cut recovery). Propagules are dispersed through a distance-decay kernel, scaled by age class.
4. Germination and establishment: if dispersal occurs, new agents (stands) may be created in unoccupied active patches that meet suitability (iSDM probabilities) and resistance conditions, initializing with age=0 and a baseline surface (5 m²). 
5. Visualization and monitoring: the model dynamically updates the visual size of agents, tracks occupied surface through plots, and allows exporting management summaries.

This modelling framework is designed for both retrospective validation (2008–2023, using temporal presence data from field and Google Street View) and prospective exploration of alternative management scenarios, and potentially climate or land-use change scenarios. It thus provides a spatially explicit, process-based tool to analyse the expansion dynamics of A. altissima and to support decision-making under different ecological and management conditions.




## HOW TO USE IT
1. Setup: Press setup to load GIS layers, initialize active patches (1 km road buffer), and create initial stands from the 2008 presence polygons.
2. Go: Press go to run the simulation tick by tick (1 tick = 1 year).
3. Management controls: Use interface switches to activate management strategies (cut, cut+revegetation) and sliders to set their frequency.
4. Visualization: Patch colours indicate environmental attributes (e.g., resistance, agriculture zones) and agents (stands) vary in size proportional to their surface area. Plots display the number of stands and total occupied surface through time.
5. Export: Use buttons to export summaries of stand trajectories and management events to CSV for analysis.


## THINGS TO NOTICE
• Observe how stands expand clonally until they approach their logistic limit, and how local resistance slows growth.
• Notice the effect of management: stands are reset to a small baseline size, and after cut+revegetation, local resistance values increase.
• See how new stands establish more frequently in high-suitability patches and less in areas of high resistance.
• Compare expansion trajectories across habitats (road verges, urban zones, riparian patches).


## THINGS TO TRY
• Run the model without management to see natural expansion from 2008–2023, then compare with observed data.
• Apply different management scenarios:
   - Annual vs. quadrennial cutting.
   - Cut vs. cut+revegetation.
   - Restrict management to subzones (e.g., riparian-road intersections only).


## EXTENDING THE MODEL
• Include native vegetation dynamics explicitly (as agents or as resistance feedback).
• Add disturbance processes (e.g., fire, drought pulses) that influence resistance. 
• Add wind directional influence to dispersal procedures.
• Add a mortality procedure.
• Implement stand merging rules, where adjacent stands coalesce into larger patches.
• Link to climate change scenarios by updating iSDM habitat suitability layers over time.
• Incorporate economic costs of management to evaluate cost-effectiveness.


## NETLOGO FEATURES
• The model integrates GIS extensions to load rasters and shapefiles (DEM, SIPNA, iSDM outputs).
• Kernel dispersal is implemented through matrix operations over patches.
• Management histories are stored as turtle-level attributes and exported via NetLogo’s file I/O functions.


## RELATED MODELS
Seed dispersal models in NetLogo tutorials (e.g., Wilensky 1999, Fire or Moths).


## CREDITS AND REFERENCES

Author: Jessica Bernal Borrego - PhD Candidate - University of Córdoba (Spain)

Acknowledgments: This model was developed in the framework of the DesFutur project (University of Córdoba), with support from field and remote sensing data (Google Street View, SIPNA/SIOSE, DEMs).

References:
• Kowarik, I., & Säumel, I. (2007). Biological flora of Central Europe: Ailanthus altissima. Perspectives in Plant Ecology, Evolution and Systematics.
• Radtke, A., Ambraß, S., Zerbe, S., Tonon, G., Fontana, V., Ammer, C. (2013). Traditional coppice forest management drives the invasion of Ailanthus altissima and Robinia pseudoacacia into deciduous forests.
• Sladonja, B., Sušek, M., Guillermic, J. (2015). Ailanthus altissima (Mill.) Swingle: a tree with a strong invasive character.
• Additional references for GIS datasets: SIPNA/SIOSE, Google Street View, DEM (IGN Spain).
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
