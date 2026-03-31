# Spanish Session Candidate Mining

Real-session review queue for Spanish sentiment evidence.

## Corpus

- Messages scanned: 2876
- Top projects: tokamak(1009), wuwei(304), kc_raven(293), qinqin(236), driftkit(207), kc_nuevo_rumbo(202), SentimentKit(173), courses(166), lql(91), frr.dev(57)
- Input files: sentimentkit_claude_es_detected.jsonl(1949), sentimentkit_codex_es_detected_v2.jsonl(927)

## profanity

### `la puta madre` (1 hits, keep)

- Rationale: Direct vulgar outburst with no technical ambiguity.
- Example: `la puta madre... Ni hablar.  Revisa primero el backend y me dices qué cosas debemos testar a nivel unitario y tambien qué propiedades deberíamos testar con pbt`

### `hasta los cojones` (1 hits, keep)

- Rationale: Strong vulgar frustration phrase in real sessions.
- Example: `es la segunda vez que me pasa esto y estoy hasta los cojones. quiero impedir que vuelva a ocurrir.  Revisa las issues delinear y veras una de new-linear que está bloqueada porque no podemos acceder al puto hetzner. crea `

## frustration

### `ni hablar` (2 hits, keep)

- Rationale: Clear rejection/frustration marker in Spanish.
- Example: `la puta madre... Ni hablar.  Revisa primero el backend y me dices qué cosas debemos testar a nivel unitario y tambien qué propiedades deberíamos testar con pbt`
- Example: `ni hablar, extiende basedpyright a todo el código de kc_raven y a ver qué sale. lo que salga lo arreglamos. Aqui no se hacen chapuzas, ni siquiera cuando se heredan, amigo`

### `qué raro` (1 hits, keep)

- Rationale: Common mild-frustration signal in technical discussion.
- Example: `joder, qué raro... bueno adelante. asegúrate de buscar online el top ten 2026 de owasp a la hora de crear el skill. No me hagas maldonadas y uses el de 2019!`

### `no me convence` (1 hits, keep)

- Rationale: Clear negative judgement without profanity.
- Example: `veamos la skill types. Estoy mirando el codigo swift de tokamak y veo a menudo que usas los opcionales de una manera que me parece de vagos y temerarios: usas nil como sustituo de un valor "nulo" específico del tipo en c`

## must_not_match

### `hay un problema` (5 hits, review)

- Rationale: Descriptive technical phrase; should stay neutral by default.
- Example: `hay un problema, mi replmprincipal es claude code y tu workflow parece indicar que es el shell. como puedo lanzar nuevas sesiones de claude (con o sin worktree) desde claude code? Y que se abra en otra pestaña de ghostti`
- Example: `no funciona. el hay un problema con el certificado`
- Example: `hay un problema, el teléfono es nuestro identificador unico. Si no tiene teléfono, como cojones sabemos quien es??? Cuantos mas anuncios sin teléfono hay? Es muy raro que haya anuncios sin teléfono: para qué cojones se a`

## positive

### `perfecto` (15 hits, review)

- Rationale: Useful positive signal but often a short workflow acknowledgment.
- Example: `Implement the following plan:  # Plan: Clase intermedia — Herramientas y Frameworks  ## Contexto  Tras la clase 1 (entender por qué fallan los LLMs) y antes de la clase 2 (restricciones con AGENTS.md), falta una clase qu`
- Example: `Implement the following plan:  # Plan: Notebook 4.mandamientos_adversariales.ipynb  ## Contexto  Es el último notebook de notes de la clase 01. Cierra la sesión condensando todo lo aprendido (redes neuronales, incentivos`
- Example: `perfecto, pues commit y push. Por cierto, se usa zod en ts?`

### `está bien` (10 hits, review)

- Rationale: Often just approval/workflow acknowledgement; ambiguous.
- Example: `Se me había olvidado pydantic y zod! Clave para la verificación.  yo haría un proyecto tipo crud, pero no sé qué tematica usar y si usar un api existente o hacer todo de cero. En caso de todo de cero, habría que generar `
- Example: `está bien`
- Example: `ahora está bien.`

## Notes

- `hay un problema` stays out of sentiment dictionaries: descriptive, not affective.
- Short approvals like `está bien` and `perfecto` need more curation before promotion.
