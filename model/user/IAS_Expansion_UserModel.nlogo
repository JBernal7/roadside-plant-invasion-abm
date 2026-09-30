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
;  min-sup-for-reproduction  ;; minimal surface (m²) to allow reproduction
  sterile-years-cut         ;; years with zero reproduction after "cut"
  sterile-years-reveg       ;; years with zero reproduction after "cut+revegetation"
  gamma-recovery            ;; years for post-cut ramp to reach full effect (e.g., 3)
  dispersal_radius_m        ;; radio de dispersión en metros
  kernel_decay              ;; parámetro de decaimiento exponencial
  kernel_a                  ;; escala del kernel
  management_reset_size     ;; superfcie de rodal tras manejo
  ;; --- resistencia biótica ---
;  a                         ;; mínimo del mapeo lineal de resistencia (penalización basal)
  b_minus_a                 ;; amplitud del mapeo: b = min(1, a + b_minus_a)
  r_weight_estab            ;; exponente (curvatura) en establecimiento
  r_weight_growth           ;; exponente (curvatura) en crecimiento

  patch-w-m
  patch-h-m
  patch-area-m2
  kernel-offsets            ;; list of [offx offy prob]
  kernel-cumprobs           ;; cumulative probs for fast sampling
  max-dispersal-attempts    ;; cap for speed

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
  inside-management?  ;; inside the management area (for predefined management polygon use)

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
  ask patches [
    set occupied? false
    set management-zone? false
    set revegetated? false
    set inside-management? false
  ]
  load-presence-map
  load-elevation-map
  gis:set-world-envelope-ds gis:envelope-of elevation-map  ;; define el marco para NetLogo
  set-patch-metrics
  initialize-elevation           ;; charges the elevation map in the visual interface
  color-by-elevation             ;; colour range for the elevation map visualized

  ;; --- capas auxiliares / dibujo ---
  set agri-layer gis:load-dataset "abm_prep/agriculture_control.asc"
  initialize-agriculture-zones
  set road-map gis:load-dataset "abm_prep/roads.shp"
  set river-map gis:load-dataset "abm_prep/rivers.shp"
  set urban-map gis:load-dataset "abm_prep/urban_areas.shp"
  set topo-nuclei-map gis:load-dataset "abm_prep/topo_nucleos.shp"
  draw-reference-layers
  draw-nucleus-names
  plot-size-distribution

  ;; --- parámetros de modelo calibrado (los más importantes se pasan a interfaz para que el usuario pueda probar efectos)  ---
  set gamma-recovery           1.9343862
  set maturity-age-years       4
;  set min-sup-for-reproduction 61.9331654
  set sterile-years-cut        0
  set sterile-years-reveg      4
  set management_reset_size    11.9673609
  set r_weight_growth          4.7954222
  set r_weight_estab           0.8890974
  set dispersal_radius_m       350
  set kernel_decay             0.003627
;  set a                        0.7799191
  set b_minus_a                0.5419241

  ;; --- presencias iniciales ---
  create-IAS-from-polygons       ;; centroid based
  refresh-occupancy              ;; synchronizes occupied patches with current IAS agents
  update-visibility

  ;; --- resistencia, máscara activa, idoneidad ---
  set resistancebio-map gis:load-dataset "abm_prep/resistance_bio_10m.asc"
  initialize-resistance-bio
  set active-mask gis:load-dataset "abm_prep/area_activa_binaria.asc"
  initialize-active-mask
  set habitatsuit-map gis:load-dataset "abm_prep/Ailanthus_ABM10m_probs.asc"
  initialize-habitat-suitability

  ;; --- kernel ---
  set kernel_a           2.08
  set max-dispersal-attempts 10
  build-kernel-matrix
  build-kernel-sampler

  update-rodal-size
  set start-year 2008

  set-current-plot "Total stand surface over time"
  set-current-plot-pen "total"
  plotxy start-year (sum [sup-actual] of turtles)

  reset-ticks

end

; ----------------------------------------------------------------
; ------------ Initialization proceedings ------------------------
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

to refresh-occupancy
  ask patches [
    set occupied? false
  ]

  ask patches with [ any? turtles-here ] [
    set occupied? true
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

to load-predefined-management-area
  let shp user-file
  if shp = false [ stop ]

  set cut-management gis:load-dataset shp

  ask patches [
    set inside-management? gis:intersects? cut-management self
    set management-zone? false
  ]

  update-visibility

  user-message "Predefined management area loaded."
end

; ----------------------------------------------------------------
; Logistic growth curve for Ailanthus stands
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

      ;; post-cut ramp factor g(t)  (safe against gamma-recovery <= 0)
      let tsince (ifelse-value (last-managed-tick >= 0) [ticks - last-managed-tick] [1e9])
      let cutlike? member? last-management-type ["cut" "cut+revegetation" "auto-agriculture"]
      let gamma-safe max list 1e-6 gamma-recovery

      let g (ifelse-value (cutlike? and tsince < 1e8)
                [ min (list 1 (tsince / gamma-safe)) ]
                [ 1 ])

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

; ----------------------------------------------------------------
; Dispersal and establishment of Ailanthus offspring
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

  ;; kernel_a now used as dispersal INTENSITY (expected attempts),
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

  ;; post-cut ramp factor g(t) for reproduction (safe)
  let cutlike? member? last-management-type ["cut" "cut+revegetation" "auto-agriculture"]
  let gamma-safe max list 1e-6 gamma-recovery
  let g (ifelse-value (cutlike? and tsince < 1e8)
            [ min (list 1 (tsince / gamma-safe)) ]
            [ 1 ])

  report vigor * g
end


to update-visibility
  ;; Show predefined management area when activated
  if management-enabled? and use-predefined-management-area? [
    ask patches with [inside-management?] [
      set pcolor cyan
    ]
  ]

  ;; Control de visualización de parches ocupados
  ifelse show-occupied-patches? [
    ask patches with [occupied?] [
      set pcolor red
    ]
  ] [
    ask patches with [occupied?] [
      ifelse inside-management? and
      management-enabled? and
      use-predefined-management-area? and
      ticks >= management-start-tick
      [
        set pcolor cyan
      ]
      [
        if is-number? elevation [
          set pcolor scale-color brown elevation 200 2000
        ]
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
  if use-predefined-management-area? [
    if ticks >= management-start-tick [
      ask patches with [inside-management?] [
        set management-zone? true
        set pcolor cyan
      ]
    ]
  ]

  if not use-predefined-management-area? [
    if draw-zone? and mouse-down? [
      let p patch mouse-xcor mouse-ycor
      ask p [
        set management-zone? true
        set pcolor cyan
      ]
    ]
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
; ----------------------------------------------------------------

to apply-management
  ;; Increase biotic resistance in revegetated areas (capped at 1.0)
  if management-type = "cut+revegetation" [
    ask patches with [management-zone? and not agri-zone?] [
      set resistance-bio min (list (resistance-bio + 0.2) 1.0)
      set revegetated? true
    ]
  ]

  ;; If eradication is implemented, eliminate A. altissima and apply revegetation
  if management-type = "eradication" [
    ask patches with [management-zone? and not agri-zone?] [
      set resistance-bio min (list (resistance-bio + 0.2) 1.0)
      set revegetated? true
    ]
  ]

  ;; Apply treatment to the stands (turtles) in management zones
  ;; If frequency is "once", avoid retratment of previously managed stands
  ask turtles with [
    [management-zone?] of patch-here and
    not [agri-zone?] of patch-here and
    (management-frequency != "once" or not managed?)
  ] [

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

    ;; Apply ERADICATION (Target plant is completely eradicated under this treatment)
    if management-type = "eradication" [
      set sup-actual 0
      set sup-teorica 0
      set color blue
      ask patch-here [
        set occupied? false
      ]
      die
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
  ;; Open output file (overwrite if exists) !NOTE: rename or deleted previous one if exists, as it could be overwriten
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


; -----------------------------------------------------------------
; ------------------------ TO GO ----------------------------------

to go

  update-rodal-size
  update-visibility

  display


  growth-phase

    ; Apply automatic control in agricultural areas
  ask turtles with [ [agri-zone?] of patch-here ] [
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
      if use-predefined-management-area? [
        ask patches with [inside-management?] [
          set management-zone? true
        ]
      ]

      apply-management
      update-rodal-size
    ]

  ]

  reproduction-and-dispersal
  refresh-occupancy
  update-rodal-size
  update-visibility

  ;; Plot surface over time
  if ticks mod 1 = 0 [  ;; cambiar a 5, 10, etc., para trazar solo cada X años
  let total-surface sum [sup-actual] of turtles
  set-current-plot "Total stand surface over time"
  set-current-plot-pen "total"
  plotxy (start-year + ticks) total-surface
 ]

  tick

  let total-surface sum [sup-actual] of turtles
  set-current-plot "Total stand surface over time"
  set-current-plot-pen "total"
  plotxy (start-year + ticks) total-surface

  display  ;; display all the changes made during this tick
  if ticks >= 37 [ stop ]

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
536
574
912
743
Total stand surface over time
Time (Year)
Surface (m²)
2008.0
2045.0
0.0
100000.0
true
false
"" ""
PENS
"total" 1.0 0 -14439633 true "" ""

TEXTBOX
402
28
1305
56
DYNAMICS OF AILANTHUS ALTISSIMA EXPANSION UNDER DIFFERENT MANAGEMENT SCENARIOS
20
0.0
1

TEXTBOX
1492
475
1642
500
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
0
1
-1000

MONITOR
926
586
1067
631
Total number of stands
count turtles
17
1
11

MONITOR
926
636
1073
681
Average stand size (m²)
mean [sup-actual] of turtles
2
1
11

MONITOR
1061
636
1154
681
Max. size (m²)
max [sup-actual] of turtles
2
1
11

MONITOR
1154
636
1234
681
Median (m²)
median [sup-actual] of turtles
2
1
11

MONITOR
1071
586
1230
631
New stands (current year)
count turtles with [age = 0]
17
1
11

MONITOR
927
688
1230
733
Number of occupied patches
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
25
497
202
530
management-enabled?
management-enabled?
1
1
-1000

TEXTBOX
29
479
179
497
Enable management?
11
0.0
1

CHOOSER
24
550
203
595
management-type
management-type
"none" "cut" "cut+revegetation" "eradication"
0

TEXTBOX
27
533
177
551
Management type
11
0.0
1

CHOOSER
24
617
201
662
management-frequency
management-frequency
"once" "annual" "biennial" "quadrennial"
0

TEXTBOX
26
598
176
616
Frequency
11
0.0
1

TEXTBOX
26
667
176
685
Start tick (year)
11
0.0
1

SWITCH
337
662
513
695
draw-zone?
draw-zone?
1
1
-1000

TEXTBOX
238
672
324
690
Drawing options:
11
0.0
1

BUTTON
450
704
520
737
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
346
701
443
739
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
27
437
218
476
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
1494
294
1674
364
-------------------------------------------\n      4. EXPORT RESULTS \n-------------------------------------------
11
0.0
1

BUTTON
1490
338
1676
371
Export world (.csv)
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
1490
379
1678
412
Export management summary (.csv)
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
1491
510
1675
790
======================\n                 Quick start:\n1. Click Setup model to load data.\n2.(Optional) Toggle visual layers (stands, patches).\n3. Enable management if you want to test control actions.\n4. Choose management type, frequency, and start year.\n5. Define the treatment area: draw it manually or load a polygon (see also info tab for more info).\n6. Click Run simulation to start, or Run one year to advance step-by-step.\n7. Observe maps and charts; export results if needed.\n======================\n
11
2.0
1

TEXTBOX
1251
603
1450
621
🟩 Stands (initial)
11
66.0
1

TEXTBOX
1251
618
1443
636
🟩 Stands (managed by farmers)
11
44.0
1

TEXTBOX
1252
634
1427
653
🟩 Stands (managed by cutting)
11
25.0
1

TEXTBOX
1252
647
1467
665
🟩 Stands (managed by cut + revegetation)
11
105.0
1

TEXTBOX
1252
661
1402
679
🟫 Occupied patches
11
15.0
1

TEXTBOX
1252
675
1402
693
⬜ Roads
11
5.0
1

TEXTBOX
1252
687
1402
705
⬜ Urban settings
11
17.0
1

TEXTBOX
1252
701
1402
719
🟦 Rivers
11
104.0
1

TEXTBOX
1252
715
1402
733
🟫 Management zones
11
85.0
1

TEXTBOX
1251
580
1401
598
Legend:\n
11
0.0
1

TEXTBOX
26
681
195
725
tick = 0  → year 2008; tick = 15 → year 2023; tick = 22 → year 2030; etc.
9
1.0
1

SLIDER
25
709
202
742
management-start-tick
management-start-tick
0
30
17.0
1
1
NIL
HORIZONTAL

SWITCH
336
576
514
609
use-predefined-management-area?
use-predefined-management-area?
1
1
-1000

TEXTBOX
235
580
328
621
Use predefined management area?
11
0.0
1

TEXTBOX
29
283
179
311
Reproduction gate main param (min. surface for reproduction)
11
0.0
1

TEXTBOX
27
360
177
388
Biotic resistance main param (basal resistance)
11
0.0
1

SLIDER
24
392
200
425
a
a
0
1
0.7799191
0.01
1
NIL
HORIZONTAL

SLIDER
24
316
200
349
min-sup-for-reproduction
min-sup-for-reproduction
10
250
61.9331654
0.01
1
m²
HORIZONTAL

BUTTON
1490
421
1677
454
Export raster files (.asc)
export-asc
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
700
767
1029
785
Developed within the DesFutur project at the University of Córdoba
11
0.0
1

TEXTBOX
713
783
1038
801
Funding details and acknowledgements are provided in the Info tab.
9
0.0
1

BUTTON
233
616
395
649
Load management area
load-predefined-management-area
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
234
701
338
740
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

@#$#@#$#@
## WHAT IS IT?

This is a spatially explicit agent-based model (ABM) designed to simulate the
expansion of *Ailanthus altissima* (tree-of-heaven) along Mediterranean road
corridors. The model represents vegetative stands rather than individual trees
as agents. Stands grow clonally, reproduce, disperse propagules, establish new
stands, and respond to management interventions.

The model was developed and parameterised using observations from the
Capileira–Los Guájares road corridor in Granada, southern Spain. Model
parameters were calibrated against the observed cumulative expansion of
*A. altissima* between 2008 and 2023 using field observations and historical
street-level imagery.

The model has two main purposes:

1. To reproduce broad corridor-scale invasion dynamics using a process-based
   representation of stand growth, reproduction, dispersal, environmental
   filtering and management.

2. To provide a reusable framework for exploring alternative management
   interventions, including treatment type, frequency, timing and spatial
   extent.

The manuscript associated with this model evaluates three treatment-intensity
levels:

- Low intensity: a single cutting intervention.
- Intermediate intensity: annual cutting combined with revegetation.
- High intensity (eradication): complete removal of existing stands combined
  with revegetation.

The user interface allows these underlying treatment types and frequencies to
be combined more flexibly than in the predefined manuscript scenarios.


## HOW IT WORKS

### Agents

Agents represent vegetative stands of *Ailanthus altissima*, rather than
individual trees. This stand-level representation provides an operational
abstraction for modelling clonal expansion, reproductive development,
dispersal and management response.

Each stand stores:

- age;
- initial stand surface (`sup-inicial`);
- current stand surface (`sup-actual`);
- theoretical stand surface derived from the growth curve (`sup-teorica`);
- previous management status;
- timing and number of management interventions; and
- the most recent management type.

Initial age is inferred from the observed height category and should therefore
be interpreted as an ontogenetic proxy rather than exact chronological age.


### Spatial environment

Spatial inputs are supplied as GIS rasters and vector layers. Environmental
rasters are generally provided at 10-m resolution, but NetLogo patches do not
represent 10 × 10 m cells. The NetLogo world is mapped to the GIS envelope, and
the physical dimensions of each model patch are calculated dynamically from
the spatial extent and NetLogo world dimensions. In the current study area,
patches are approximately 59 × 85 m.

Only patches belonging to the active model domain, defined by the approximately
1-km buffer around the study road corridor, can receive new stands.

Each patch can contain:

- habitat-suitability values derived from an invasive species distribution
  model (iSDM);
- a biotic-resistance index derived from SIPNA/REDIAM habitat information;
- agricultural-management status;
- management-zone status; and
- elevation.

Roads, rivers, urban nuclei and place names are included primarily as spatial
reference and visualisation layers.

Biotic resistance directly modifies stand growth and establishment probability.
Its effect on reproduction is indirect, through its influence on stand growth
and therefore on whether reproductive-size thresholds are reached.

Agricultural areas are represented separately from biotic resistance. Stands
located in actively managed agricultural areas are automatically reset each
year to a small post-treatment surface, representing recurrent background
control.


### Initialisation

The simulation starts in 2008.

Observed *A. altissima* polygons assigned to 2008 are used to initialise
the invasion. One stand agent is positioned at the centroid of each initial
polygon. Patch occupancy is then derived from the presence of stand agents, so
the model patch containing each initial stand centroid is marked as occupied.

Initial stand attributes are obtained from the observation dataset where
available. Initial stand surface is based on the corresponding stand-surface
attribute, while age is estimated from height category and stand size.

The theoretical stand surface for each age is calculated using the empirical
logistic growth relationship implemented in `logistic-surface`.


### Annual simulation cycle

One tick represents one year. During each annual step, the model performs the
following processes:

1 **Clonal growth**

   Stand age increases and stand surface grows according to an empirically
   fitted logistic growth curve. Annual growth is reduced according to local
   biotic resistance and, where applicable, post-treatment recovery.

2 **Background agricultural control**

   Stands occurring within actively managed agricultural patches are reset
   annually to the post-treatment baseline size. These interventions are
   recorded as `auto-agriculture`.

3 **Optional targeted management**

  Management can be applied within interactively selected treatment zones or 
  externally supplied predefined polygons. 

  Available treatment types are:

   - `cut`: stand surface is reduced to the post-treatment baseline;
   - `cut+revegetation`: stand surface is reduced and local biotic resistance
     is increased;
   - `eradication`: existing stands are removed and local biotic resistance is
     increased through the revegetation effect.

   Management can be applied once, annually, biennially or quadrennially from
   a user-selected starting year.

4 **Reproduction and dispersal**

   Reproduction is conditional on stand age, stand surface, management-related
   sterile periods and post-treatment recovery.

   Reproductive stands generate dispersal attempts according to reproductive
   capacity and age. Destination patches are sampled from a precomputed
   exponential distance-decay dispersal kernel truncated at the specified
   maximum dispersal radius.

5 **Establishment**

   A dispersed propagule can establish only in an unoccupied active patch.
   Establishment probability is jointly determined by habitat suitability and
   the patch-level biotic-resistance function.

   Successful establishment generates a new stand with age 0 and an initial
   surface of 5 m².

6 **Monitoring and visualisation**

   Stand size and occupied patches are updated graphically, and the interface
   displays stand abundance, occupied patches, stand-size statistics and total
   simulated stand surface through time.


## HOW TO USE IT

1 **Set up the model**

   Press `Setup model` to load the spatial inputs, initialise the active domain
   and create the 2008 stands.

2 **Inspect or modify key parameters**

   The interface exposes selected parameters, including the minimum stand
   surface required for reproduction and the lower-bound biotic-resistance
   parameter.

3 **Configure management**

   Activate `management-enabled?` if targeted management is required.

   Select:

   - management type;
   - management frequency; and
   - management starting tick.

   Tick 0 corresponds to 2008. For example, tick 17 corresponds to 2025.

4 **Define a treatment zone**

   Treatment areas can be defined in two ways.

   **Manual selection**

   Leave `use-predefined-management-area?` OFF. Treatment patches can then be
   selected interactively using the drawing tool or the rectangle-selection
   tool. For freehand selection, activate `draw-zone?`, start the `Draw zone`
   button, and draw directly on the map.

   **Predefined spatial polygon**

   Press `Load management area` and select a polygon shapefile. Then activate
   `use-predefined-management-area?`. The loaded polygon defines the spatial
   area in which targeted management will operate.

   When a predefined polygon is used, `draw-zone?` should remain OFF and the
   `Draw zone` button is not required.

   External management polygons must use a spatial reference compatible with
   the model inputs and overlap the active simulation domain.

5 **Run the model**

   Use `Run simulation` for continuous execution or `Run one year` to advance
   the model one annual step at a time.

6 **Inspect outputs**

   Use the map, monitors and occupied-surface plot to examine simulated
   invasion dynamics.

7 **Export results**

   The interface can export:

   - the NetLogo world state;
   - current stand and management attributes to CSV; and
   - binary occupancy rasters for spatial post-processing.


## THINGS TO NOTICE

- Stand growth is constrained by the logistic growth relationship and local
  biotic resistance.
- Reproductive output depends on both stand age and stand surface.
- Establishment is more likely where habitat suitability is high and effective
  biotic resistance is low.
- Cutting reduces current stand size but allows subsequent recovery.
- Cutting combined with revegetation additionally increases local resistance.
- Eradication removes existing treated stands, but untreated or newly
  established stands can remain elsewhere in the simulated landscape.
- Recurrent agricultural management operates independently of the targeted
  management scenario.


## THINGS TO TRY

To reproduce the treatment-intensity structure used in the associated
manuscript, set the management start to tick 17 (2025) and compare:

- **Low intensity:** `cut` + `once`
- **Intermediate intensity:** `cut+revegetation` + `annual`
- **High intensity (eradication):** `eradication` + `once`

These treatments can be applied to manually defined areas or to predefined spatial polygons, including the treatment-zone layers used in the associated study

The interface can also be used to explore combinations outside the manuscript
scenario design, for example:

- annual versus biennial or quadrennial treatment;
- different treatment starting years;
- alternative manually defined treatment zones;
- externally supplied predefined management polygons; and
- simulations without targeted management.


## MODEL SCOPE AND EXTENSIONS

The current model represents stand growth, reproduction, dispersal,
environmental filtering and management. Several processes are intentionally
simplified or held static.

Potential extensions include:

- dynamic native-vegetation responses;
- disturbance processes such as fire or drought;
- directionally explicit wind-mediated dispersal;
- explicit stand mortality;
- merging of adjacent stands;
- temporally dynamic habitat-suitability layers under climate or land-use
  change; and
- economic costs and cost-effectiveness of management.


## NETLOGO FEATURES

- NetLogo GIS extension for raster and vector spatial inputs.
- Spatially explicit stand agents and patch-level environmental attributes.
- Precomputed exponential distance-decay dispersal kernel using physical
  patch dimensions derived from the GIS envelope.
- Management zones defined interactively or from externally supplied polygon layers.
- Stand-level management histories.
- CSV, NetLogo-world and raster outputs for subsequent analysis.


## SOFTWARE, DATA AND REPRODUCIBILITY

Source code and reproducibility materials:

https://github.com/JBernal7/roadside-plant-invasion-abm

Archived software release:

https://doi.org/10.5281/zenodo.22833451

Associated reproducibility dataset:

https://doi.org/10.5281/zenodo.22833035

The software is distributed under the MIT License.


## CREDITS

Software and model development:

Jessica Bernal-Borrego, University of Córdoba, Spain.

Contributions:

Claudio A. Bracho-Estévanez contributed to the methodological and computational
implementation and execution of the management scenarios.

Pablo González-Moreno contributed conceptual and methodological supervision of
model development.


## FUNDING

This research was carried out within the DesFutur project, funded by Fundación Biodiversidad (MITECO) under the European Union NextGenerationEU/PRTR framework. Additional support during model development, scenario analysis and manuscript preparation was provided by the DYNAMO project (PID2023-152653OA-C22), funded by MCIN/AEI/10.13039/501100011033.

Pablo González-Moreno was also supported by grant RYC2021-033138-I, funded by MCIN/AEI/10.13039/501100011033 and the European Union NextGenerationEU/PRTR.


## DATA SOURCES

Spatial inputs include:

- SIPNA/REDIAM spatial information, Junta de Andalucía, licensed under CC BY
  4.0;
- Datos Espaciales de Referencia de Andalucía (DERA), Instituto de Estadística
  y Cartografía de Andalucía, Junta de Andalucía, licensed under CC BY 4.0;
- NASA Shuttle Radar Topography Mission (SRTM) elevation data; and
- author-generated field and retrospective observation data.

No third-party street-level imagery is redistributed; only author-derived observations and geometries are included in the associated dataset.

Complete provenance and licensing information is provided in the associated
Zenodo dataset.


## REFERENCES

Kowarik, I., & Säumel, I. (2007). Biological flora of Central Europe:
*Ailanthus altissima*. Perspectives in Plant Ecology, Evolution and
Systematics.

Radtke, A., Ambraß, S., Zerbe, S., Tonon, G., Fontana, V., & Ammer, C.
(2013). Traditional coppice forest management drives the invasion of
*Ailanthus altissima* and *Robinia pseudoacacia* into deciduous forests.

Sladonja, B., Sušek, M., & Guillermic, J. (2015). *Ailanthus altissima*
(Mill.) Swingle: a tree with a strong invasive character.

For the complete methodological description and bibliography, see the
associated manuscript and archived repository.
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
NetLogo 6.4.0
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
