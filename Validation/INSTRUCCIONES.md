# Validación contra goniómetro

Meta del MVP: que Kinesia mida con un error medio de **±5° o menos** frente a un goniómetro.
Cada medición es un video corto y el número que marcó el goniómetro en ese momento.

## Qué se necesita

- Un iPhone en un trípode, a unos 2 metros y a la altura de la articulación.
- Buena luz, ropa ajustada y el cuerpo completo dentro del cuadro.
- Un goniómetro y esta hoja (`plantilla-mediciones.csv`) para anotar.

## Cómo poner la cámara

| Ejercicio en el CSV | Qué se mide | Cámara |
| --- | --- | --- |
| `codo` | Flexión de codo | De perfil, brazo medido hacia la cámara |
| `rodilla` | Flexión de rodilla de pie | De perfil |
| `hombro-flexion` | Flexión de hombro | De perfil |
| `hombro-abduccion` | Abducción de hombro | De frente |
| `cadera-flexion` | Flexión de cadera de pie | De perfil |
| `cadera-abduccion` | Abducción de cadera de pie | De frente |
| `tobillo` | Dorsiflexión en estocada | De perfil |
| `cuello` | Inclinación lateral de cuello | De frente |

Usa la **cámara trasera** del iPhone. Si grabas con la frontal y el video sale volteado como espejo, pon `si` en la columna `espejo`.

## Cada medición

1. Empieza a grabar.
2. El paciente lleva la articulación al final de su rango y **lo sostiene 3 segundos**.
3. Mientras sostiene, mide con el goniómetro **sin tapar** las articulaciones (por ejemplo, desde el lado que no ve la cámara).
4. Detén el video (5 a 8 segundos en total) y anota el número en el CSV.

Haz **10 mediciones por articulación y por lado**, con rangos distintos (a medio camino y al final), no siempre la misma.
Nombra los videos para no confundirlos: `codo-der-01.mov`, `codo-der-02.mov`, `rodilla-izq-01.mov`…

## El CSV

Una línea por video:

```
video,ejercicio,lado,goniometro,espejo
codo-der-01.mov,codo,derecho,132,no
```

- `lado`: `izquierdo` o `derecho` (el del paciente).
- `goniometro`: los grados que marcó. Decimales con punto (`92.5`) o entre comillas con coma (`"92,5"`).
- `espejo`: `si` o `no`. Si no pones la columna, se toma `no`.

## Correr la validación (en una Mac)

Pon el CSV y los videos en la misma carpeta, por ejemplo `~/Validacion`, y desde la carpeta `kinesia-motion`:

```
swift run kinesia-validate ~/Validacion/mediciones.csv
```

Muestra cada medición y una tabla por ejercicio y lado:

- **Error medio**: el promedio de la diferencia sin signo. Pasa si es de 5° o menos.
- **Sesgo**: si Kinesia mide de más (+) o de menos (−) en promedio.
- **Máx**: la peor diferencia.
- **±5°**: qué porcentaje de las mediciones quedó dentro de ±5°.

También deja `resultados.csv` en la misma carpeta, con el detalle de cada video, para abrirlo en Excel o Numbers.

Si una medición dice que no se vieron las articulaciones, revisa que el cuerpo completo esté en el cuadro y que la cámara esté de perfil o de frente como dice la tabla.
