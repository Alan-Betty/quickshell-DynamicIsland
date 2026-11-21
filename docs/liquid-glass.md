# How the liquid glass works

Liquid glass isn't a transparent colour. A pane of tinted alpha looks like cellophane. What makes glass read as glass is what it does to the things behind it: the edge bends them, the body softens them, the surface catches light. The island does all three, in one fragment shader, `shared/shaders/liquidglass.frag`.

## Where it's used

The island itself is black. Glass is only on controls: the Control Center toggles and power buttons, the tab switcher's thumb, the play buttons, the header buttons, the tray beads and tiles, the switch knob while you hold it, the notification close bead and action pills, and the launcher's selection.

That split is deliberate. A whole island made of glass fights with whatever is on your wallpaper. A black island with glass controls looks like a device, and the glass has something to do: on the Media tab it bends the album art, and on black it reads as a lit bead.

## The pipeline

Each control is a `GlassControl`, a `ShaderEffect` sized to the control plus a few pixels of padding for its shadow. Per pixel:

1. **Shape.** A signed distance field for a rounded rectangle gives the distance to the nearest edge and the direction of that edge. Coverage is anti-aliased from the same distance.
2. **Bevel.** The distance is mapped onto a circular profile: flat across the middle, curving down to vertical at the rim. The slope of that curve becomes a surface normal, tilted outwards near the edge.
3. **Refraction.** The view ray is bent through the normal with Snell's law, using the refractive index of crown glass (1.52). The bend tells the shader where to sample the backdrop. Near the rim the sample point moves inwards, so content magnifies towards the edge the way it does under a real lens.
4. **Frost.** The backdrop is read through a ten-tap spiral blur. It samples a mip level matched to the tap spacing and rotates the spiral per pixel, so the blur is smooth with no ghost copies. The red and blue channels are offset slightly in opposite directions at the rim, which gives the faint colour fringe of dispersion.
5. **Material.** Saturation is lifted (vibrancy), the result is mixed a little towards white (the milky body), and an optional tint is applied. A tinted toggle is the same glass with the tint turned up.
6. **Light.** A soft sheen falls from the top. The edge darkens slightly where the glass is thickest. A specular rim is lit from the top left, with a weaker bounce on the opposite corner. A fine grain stops the frost from looking like a gradient.

The output is premultiplied, with a soft contact shadow outside the shape.

## What a control refracts

A `GlassControl` looks up its parents for the nearest item that declares three properties:

```qml
property var glassSource      // a ShaderEffectSource of the backdrop
property Item glassSpace      // the item that texture covers
property color glassBase      // the surface colour around it
```

The island offers its ambient layer, the blurred album art, while that layer is showing. The rest of the time `glassSource` is null, and the shader skips sampling entirely and uses `glassBase` instead, so a toggle on plain black costs almost nothing. Notification cards and the OSD offer their own surface colour the same way.

## Settings

- **Liquid Glass** turns the shader off and draws a flat fill instead. Use it on a weak GPU or if you simply prefer flat controls.
- **Glass Strength** scales the refraction and the rim together, from 40 % to 160 %.

The parameters a component can set: `radius`, `tint`, `tintAmount`, `frost`, `blur`, `strength`, `shadow`, `hovered` and `pressed`. Hovering and pressing brighten the sheen and the rim, and the caller usually adds a small spring on `scale`.

## Rebuilding the shader

The `.qsb` next to the source is what Quickshell loads. After editing the GLSL:

```bash
tools/build-shaders.sh   # needs qsb from qt6-shadertools
tools/sync.sh            # copies the result into every package
```

If the shader fails to load, the control falls back to the flat fill on its own. The log says why.
