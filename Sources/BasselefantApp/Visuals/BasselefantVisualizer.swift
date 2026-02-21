import SwiftUI

struct BasselefantVisualizer: View {
    let feature: AudioFeature
    let style: VisualStyle
    let dynamicsPreset: VisualDynamicsPreset
    let dynamicsTuning: VisualDynamicsTuning
    let audioMapProfile: VisualAudioMapProfile

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                switch style {
                case .denseMonolith:
                    drawHeroScene(context: &context, size: size, t: t)
                case .ultraMinimal:
                    drawMinimalScene(context: &context, size: size, t: t)
                case .industrialEmblem:
                    drawEmblemScene(context: &context, size: size, t: t)
                }
            }
        }
    }

    // MARK: - Hero Scene
    private func drawHeroScene(context: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let motion = dynamicsPreset
        let tuning = dynamicsTuning
        let driftScale = motion.cameraDriftScale * tuning.cameraDriftMultiplier
        let beatScale = motion.cameraBeatScale * tuning.cameraBeatMultiplier
        let mapped = audioMapProfile.map(low: feature.eqLow, mid: feature.eqMid, high: feature.eqHigh, flux: feature.spectralFlux)
        let eqLow = mapped.low
        let eqMid = mapped.mid
        let eqHigh = mapped.high
        let driftSlowX = sin(t * (0.11 + eqMid * 0.1)) * (0.018 + feature.energy * 0.01) * driftScale
        let driftSlowY = cos(t * (0.09 + eqLow * 0.08)) * (0.014 + feature.energy * 0.008) * driftScale
        let beatKick = sin(t * (1.4 + feature.tempoEstimate / 95.0)) * feature.pulse * 0.02 * beatScale
        let cameraOffset = CGSize(
            width: size.width * (driftSlowX + beatKick * 0.55),
            height: size.height * (driftSlowY - beatKick * 0.35)
        )
        drawVortexBackground(
            context: &context,
            size: size,
            t: t,
            cameraOffset: cameraOffset,
            dynamicsPreset: motion,
            dynamicsTuning: tuning
        )

        let center = CGPoint(
            x: size.width * 0.5 + cameraOffset.width * 0.18 * motion.cameraFollowScale,
            y: size.height * 0.56 + cameraOffset.height * 0.16 * motion.cameraFollowScale
        )
        let scale = min(size.width, size.height) * 0.52
        let danceScale = motion.elephantDanceScale * tuning.elephantDanceMultiplier
        let sway = sin(t * (0.86 + feature.pulse * 2.9 + feature.spectralFlux * 0.5)) * (0.02 + feature.pulse * 0.05) * danceScale
        let bounce = sin(t * (1.95 + eqLow * 3.8)) * (0.015 + eqLow * 0.052) * danceScale
        let sideStep = sin(t * (1.05 + eqLow * 2.4)) * (0.018 + eqLow * 0.045) * danceScale
        let dancePump = 1.0 + sin(t * (1.35 + feature.pulse * 3.1)) * (0.016 + feature.energy * 0.025 + feature.spectralFlux * 0.01) * danceScale
        let earLift = sin(t * (1.0 + eqHigh * 1.9 + eqMid * 0.8)) * (0.03 + feature.energy * 0.03) * danceScale
        let trunkShift = sin(t * (1.4 + feature.pulse * 3.0 + eqLow * 0.9)) * (0.06 + eqLow * 0.12) * danceScale

        let transform = CGAffineTransform.identity
            .translatedBy(x: center.x + scale * sideStep, y: center.y + scale * bounce)
            .scaledBy(x: scale * dancePump, y: scale * dancePump)
            .rotated(by: sway)

        let outline = elephantOutline(trunkShift: trunkShift, earLift: earLift).applying(transform)
        // Opaque matte so background vortex does not shine through the elephant.
        context.fill(outline, with: .color(Color(white: 0.18)))
        var clipped = context
        clipped.clip(to: outline)
        drawFacetFill(context: &clipped, transform: transform, trunkShift: trunkShift, earLift: earLift, t: t)
        drawInternalTexture(context: &clipped, bounds: outline.boundingRect, t: t)

        context.stroke(
            outline,
            with: .color(.white.opacity(0.6 + feature.treble * 0.2)),
            style: StrokeStyle(lineWidth: 1.5 + feature.treble * 1.2, lineJoin: .round)
        )
        drawTusksAndEyes(context: &context, transform: transform, trunkShift: trunkShift)
        drawBirds(context: &context, transform: transform, size: size, t: t)
        drawStrobe(context: &context, size: size, t: t)
    }

    private func drawVortexBackground(
        context: inout GraphicsContext,
        size: CGSize,
        t: TimeInterval,
        cameraOffset: CGSize,
        dynamicsPreset: VisualDynamicsPreset,
        dynamicsTuning: VisualDynamicsTuning
    ) {
        let center = CGPoint(x: size.width * 0.5 + cameraOffset.width, y: size.height * 0.55 + cameraOffset.height)
        let maxR = hypot(size.width, size.height) * 0.78
        let mapped = audioMapProfile.map(low: feature.eqLow, mid: feature.eqMid, high: feature.eqHigh, flux: feature.spectralFlux)
        let eqLow = mapped.low
        let eqMid = mapped.mid
        let eqHigh = mapped.high
        let breathRateScale = dynamicsPreset.breathSpeedScale * dynamicsTuning.breathSpeedMultiplier
        // Very slow inhale/exhale + soft squash/stretch for a deeper tunnel feel.
        let breath = sin(t * (0.085 + feature.energy * 0.03) * breathRateScale)
        let squash = sin(t * (0.058 + eqMid * 0.07 + feature.spectralFlux * 0.03) * breathRateScale + .pi / 2)
        let radialScale = 1.0 + breath * (0.1 + feature.energy * 0.04)
        let xScale = radialScale * (1.0 + squash * 0.05)
        let yScale = radialScale * (0.82 - squash * 0.09)

        let base = Gradient(colors: [
            Color(red: 0.02, green: 0.02, blue: 0.03),
            Color(red: 0.06, green: 0.05, blue: 0.08),
            Color(red: 0.01, green: 0.01, blue: 0.02)
        ])
        context.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .radialGradient(base, center: center, startRadius: 10, endRadius: maxR * radialScale))

        // Switches between color / monochrome / mostly-off based on music + time.
        let modeStep = floor(t * (0.42 + feature.tempoEstimate / 520.0 + feature.pulse * 0.45 + eqHigh * 0.15))
        let modeNoise = pseudoNoise(seed: modeStep * 0.713 + feature.tempoEstimate * 0.017 + feature.energy * 0.29 + eqHigh * 0.33)
        let mode: Int
        if modeNoise > 0.86 || (feature.energy < 0.2 && modeNoise > 0.7) {
            mode = 2 // mostly off
        } else if modeNoise > 0.56 {
            mode = 1 // black and white
        } else {
            mode = 0 // color
        }

        let pulseEnvelope = clamp(
            0.62 + feature.energy * 0.68 + feature.pulse * 0.95 + feature.spectralFlux * 0.28 + 0.11 * sin(t * (1.8 + eqMid * 2.8)),
            0,
            1.8
        )
        let modeOpacity: Double = {
            switch mode {
            case 0: return 0.92 * pulseEnvelope
            case 1: return 0.84 * pulseEnvelope
            default: return max(0.0, feature.pulse * 0.65 - 0.08)
            }
        }()

        let breakdown = feature.energy < 0.24 && feature.pulse < 0.22 && feature.spectralFlux < 0.18
        let drop = eqLow > 0.62 && feature.pulse > 0.42
        let density = clamp(
            breakdown ? 0.56 : (drop ? 1.58 : 0.9 + feature.energy * 0.55 + feature.pulse * 0.35 + feature.spectralFlux * 0.24),
            0.45,
            1.75
        )
        let contrast = breakdown ? 0.72 : (drop ? 1.38 : 1.0 + feature.pulse * 0.28 + eqHigh * 0.2)
        let opacityBoost = breakdown ? 0.68 : (drop ? 1.24 : 1.0)
        let layer2Scale = dynamicsPreset.secondaryLayerDensityScale * dynamicsTuning.layer2DepthMultiplier
        let secondaryDensity = density * layer2Scale

        let primaryArms = Int(clamp(44 * density, 18, 80))
        let secondaryArms = Int(clamp(16 * secondaryDensity, 8, 34))
        let primaryStep = max(6.4, 13.0 / max(0.75, density))
        let secondaryStep = max(10.5, 21.0 / max(0.75, secondaryDensity))

        drawVortexLayer(
            context: &context,
            center: center,
            maxR: maxR,
            t: t,
            arms: primaryArms,
            startRadius: 14,
            radialStep: primaryStep,
            spinRate: 0.24 + eqMid * 1.4 + feature.spectralFlux * 0.2,
            twist: 0.041,
            hueTime: 0.021,
            hueShift: 0,
            mode: mode,
            modeOpacity: modeOpacity * opacityBoost,
            xScale: xScale,
            yScale: yScale,
            widthBase: 0.32,
            widthGain: 10.8,
            contrast: contrast
        )

        // Parallax layer: different speed/twist gives extra depth.
        drawVortexLayer(
            context: &context,
            center: CGPoint(x: center.x - cameraOffset.width * 0.18, y: center.y - cameraOffset.height * 0.12),
            maxR: maxR * 0.96,
            t: t,
            arms: secondaryArms,
            startRadius: maxR * 0.16,
            radialStep: secondaryStep,
            spinRate: -0.13 - eqLow * 0.8,
            twist: 0.056,
            hueTime: -0.015,
            hueShift: 0.19,
            mode: mode,
            modeOpacity: modeOpacity
                * (breakdown ? 0.12 : (drop ? 0.32 : 0.22 + feature.energy * 0.14))
                * dynamicsPreset.secondaryLayerOpacityScale
                * clamp(layer2Scale, 0.35, 1.9),
            xScale: xScale * 1.05,
            yScale: yScale * 1.02,
            widthBase: 0.2,
            widthGain: 3.9,
            contrast: contrast * 0.9
        )

        // Central dark chamber to intensify tunnel pull.
        let chamberRadius = maxR
            * (0.11 + 0.03 * (1 - feature.energy) + 0.015 * sin(t * (2.4 + feature.pulse * 4.0)))
            * (0.94 + radialScale * 0.1)
            * (breakdown ? 1.15 : (drop ? 0.9 : 1.0))
        let chamberRect = CGRect(
            x: center.x - chamberRadius * (1.0 + squash * 0.04),
            y: center.y - chamberRadius * (0.88 - squash * 0.08),
            width: chamberRadius * 2,
            height: chamberRadius * (1.76 - squash * 0.16)
        )
        context.fill(Path(ellipseIn: chamberRect), with: .color(.black.opacity(0.86)))

        let rimRect = chamberRect.insetBy(dx: -chamberRadius * 0.4, dy: -chamberRadius * 0.35)
        context.stroke(
            Path(ellipseIn: rimRect),
            with: .color(.white.opacity(0.07 + feature.pulse * 0.24 + (drop ? 0.08 : 0))),
            style: StrokeStyle(lineWidth: 1.0 + feature.pulse * 2.1 + (drop ? 0.8 : 0))
        )
    }

    private func drawVortexLayer(
        context: inout GraphicsContext,
        center: CGPoint,
        maxR: Double,
        t: TimeInterval,
        arms: Int,
        startRadius: Double,
        radialStep: Double,
        spinRate: Double,
        twist: Double,
        hueTime: Double,
        hueShift: Double,
        mode: Int,
        modeOpacity: Double,
        xScale: Double,
        yScale: Double,
        widthBase: Double,
        widthGain: Double,
        contrast: Double
    ) {
        guard arms >= 3 else { return }
        for i in 0..<arms {
            let phase = (Double(i) / Double(arms)) * Double.pi * 2 + hueShift * Double.pi * 2
            var r: Double = max(14, startRadius)
            while r < maxR {
                let nextR = min(r + radialStep, maxR)
                let spinA = phase + r * twist + t * spinRate
                let spinB = phase + nextR * twist + t * spinRate
                let stretchA = 0.92 + (r / maxR) * 0.16
                let stretchB = 0.92 + (nextR / maxR) * 0.16
                let a = CGPoint(
                    x: center.x + CGFloat(cos(spinA) * r * stretchA * xScale),
                    y: center.y + CGFloat(sin(spinA) * r * stretchA * yScale)
                )
                let b = CGPoint(
                    x: center.x + CGFloat(cos(spinB) * nextR * stretchB * xScale),
                    y: center.y + CGFloat(sin(spinB) * nextR * stretchB * yScale)
                )

                var seg = Path()
                seg.move(to: a)
                seg.addLine(to: b)

                let radial = r / maxR
                let width = widthBase + pow(radial, 1.45) * (widthGain * contrast)
                let hue = (Double(i) / Double(arms) + radial * 0.35 + t * hueTime + hueShift)
                    .truncatingRemainder(dividingBy: 1)
                let color: Color = {
                    switch mode {
                    case 0:
                        let sat = clamp(0.84 * contrast, 0.54, 1.0)
                        let bri = clamp(0.92 * (0.9 + contrast * 0.16), 0.62, 1.0)
                        return Color(hue: hue, saturation: sat, brightness: bri)
                    case 1:
                        let g = clamp(0.56 + radial * 0.36 * contrast, 0.4, 0.96)
                        return Color(white: g)
                    default:
                        return Color(white: 0.95)
                    }
                }()

                context.stroke(
                    seg,
                    with: .color(color.opacity((0.04 + radial * 0.22 + feature.energy * 0.08) * modeOpacity * (0.35 + radial * 0.75))),
                    style: StrokeStyle(lineWidth: width, lineCap: .round)
                )
                r = nextR
            }
        }
    }

    private func drawFacetFill(
        context: inout GraphicsContext,
        transform: CGAffineTransform,
        trunkShift: Double,
        earLift: Double,
        t: TimeInterval
    ) {
        let facets = elephantFacets(trunkShift: trunkShift, earLift: earLift)
        let pulseBoost = feature.pulse * 0.35

        for (i, facet) in facets.enumerated() {
            let path = pathFrom(points: facet).applying(transform)
            let shade = 0.32 + Double(i % 6) * 0.09 + feature.energy * 0.16 + pulseBoost * 0.22
            let shimmer = pseudoNoise(seed: Double(i) * 0.73 + t * 0.2) * 0.12
            let level = min(0.95, shade + shimmer)
            let color = Color(white: level)
            context.fill(path, with: .color(color))
            context.stroke(
                path,
                with: .color(.white.opacity(0.24 + feature.treble * 0.24)),
                style: StrokeStyle(lineWidth: 0.9 + feature.treble * 1.1, lineJoin: .round)
            )
        }
    }

    private func drawInternalTexture(context: inout GraphicsContext, bounds: CGRect, t: TimeInterval) {
        let count = 240
        for i in 0..<count {
            let s = Double(i) * 0.313
            let x = bounds.minX + CGFloat(pseudoNoise(seed: s * 2.1 + t * 0.15)) * bounds.width
            let y = bounds.minY + CGFloat(pseudoNoise(seed: s * 3.9 - t * 0.16)) * bounds.height
            let len = 2.5 + pseudoNoise(seed: s * 9.2) * 6.0
            let a = t * 0.19 + s * 2.7
            let dx = cos(a) * len
            let dy = sin(a) * len
            var path = Path()
            path.move(to: CGPoint(x: x - dx, y: y - dy))
            path.addLine(to: CGPoint(x: x + dx, y: y + dy))
            context.stroke(
                path,
                with: .color(.white.opacity(0.08 + feature.treble * 0.16)),
                style: StrokeStyle(lineWidth: 0.75 + feature.treble * 0.75, lineCap: .round)
            )
        }
    }

    private func drawTusksAndEyes(context: inout GraphicsContext, transform: CGAffineTransform, trunkShift: Double) {
        let leftTusk = pathFrom(points: [
            CGPoint(x: -0.14, y: 0.0),
            CGPoint(x: -0.29, y: 0.12),
            CGPoint(x: -0.24, y: 0.27),
            CGPoint(x: -0.1, y: 0.11)
        ]).applying(transform)
        let rightTusk = pathFrom(points: [
            CGPoint(x: 0.14, y: 0.0),
            CGPoint(x: 0.29, y: 0.12),
            CGPoint(x: 0.24, y: 0.27),
            CGPoint(x: 0.1, y: 0.11)
        ]).applying(transform)
        context.fill(leftTusk, with: .color(.white.opacity(0.94)))
        context.fill(rightTusk, with: .color(.white.opacity(0.94)))
        context.stroke(leftTusk, with: .color(.white.opacity(0.36)), style: StrokeStyle(lineWidth: 0.9, lineJoin: .round))
        context.stroke(rightTusk, with: .color(.white.opacity(0.36)), style: StrokeStyle(lineWidth: 0.9, lineJoin: .round))

        let leftEye = polygon(
            center: CGPoint(x: -0.215, y: -0.17),
            radius: 0.036,
            sides: 5,
            rotation: .pi / 5
        ).applying(transform)
        let rightEye = polygon(
            center: CGPoint(x: 0.215, y: -0.17),
            radius: 0.036,
            sides: 5,
            rotation: .pi / 5
        ).applying(transform)
        for eye in [leftEye, rightEye] {
            context.fill(eye, with: .color(.black.opacity(0.92)))
            context.stroke(eye, with: .color(.white.opacity(0.42 + feature.energy * 0.35)), style: StrokeStyle(lineWidth: 0.9))
        }

        let top = CGPoint(x: 0.0, y: -0.245) // clearly between the eyes / forehead
        let control = CGPoint(x: 0.095 + trunkShift * 0.52, y: 0.205)
        let tip = CGPoint(x: -0.03 + trunkShift * 0.74, y: 0.79)
        let segments = 22
        for i in 0..<segments {
            let u0 = Double(i) / Double(segments)
            let u1 = Double(i + 1) / Double(segments)
            let p0 = quadPoint(a: top, b: control, c: tip, t: u0)
            let p1 = quadPoint(a: top, b: control, c: tip, t: u1)
            var seg = Path()
            seg.move(to: p0)
            seg.addLine(to: p1)
            seg = seg.applying(transform)
            let alpha = 0.015 + pow(u1, 1.55) * (0.45 + feature.pulse * 0.33) // fades upward near eyes
            context.stroke(
                seg,
                with: .color(.white.opacity(alpha)),
                style: StrokeStyle(lineWidth: 0.6 + u1 * (2.6 + feature.bass * 2.0), lineCap: .round)
            )
        }
    }

    private func drawStrobe(context: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let gate = pseudoNoise(seed: floor(t * 12) * 0.73)
        guard feature.pulse > 0.25, gate > 0.55 else { return }
        let alpha = min(0.2, 0.05 + feature.pulse * 0.2)
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white.opacity(alpha)))
    }

    private func drawBirds(context: inout GraphicsContext, transform: CGAffineTransform, size: CGSize, t: TimeInterval) {
        let perchLocal: [CGPoint] = [
            CGPoint(x: -0.52, y: -0.36),
            CGPoint(x: 0.0, y: -0.52),
            CGPoint(x: 0.52, y: -0.36)
        ]
        let perchWorld = perchLocal.map { $0.applying(transform) }
        let count = 4
        for i in 0..<count {
            let phase = fract(t * (0.046 + feature.energy * 0.018) + Double(i) * 0.24)
            let landed = phase < 0.62
            let flutter = sin(t * (5.3 + feature.pulse * 6.0) + Double(i) * 1.7)
            let wingSnap = sin(t * (11.5 + feature.pulse * 10.5) + Double(i) * 2.4) >= 0 ? 1.0 : -1.0
            let wing = clamp(
                1.0 + flutter * (0.16 + feature.energy * 0.2) + wingSnap * (0.08 + feature.energy * 0.13),
                0.62,
                1.52
            )
            let birdSize = 17.0 + feature.energy * 8.0
            let color = Color(white: 0.88 + pseudoNoise(seed: Double(i) * 0.71) * 0.1)

            let position: CGPoint
            let angle: Double
            if landed {
                let perch = perchWorld[i % perchWorld.count]
                let bobSlow = sin(t * (2.6 + feature.pulse * 2.6) + Double(i)) * (1.8 + feature.pulse * 3.5)
                let bobSnap = (sin(t * (8.4 + feature.pulse * 8.2) + Double(i) * 1.3) >= 0 ? 1.0 : -1.0)
                    * (0.7 + feature.pulse * 1.8)
                position = CGPoint(x: perch.x, y: perch.y + bobSlow + bobSnap)
                let tiltSnap = sin(t * (7.8 + feature.pulse * 6.0) + Double(i) * 1.2) >= 0 ? 0.12 : -0.12
                angle = sin(t * 0.5 + Double(i)) * 0.09 + tiltSnap
            } else {
                let orbit = Double(i) * 1.2 + t * (0.29 + feature.mid * 0.44)
                let r = min(size.width, size.height) * (0.18 + Double(i) * 0.035)
                let zig = sin(t * (6.8 + feature.pulse * 7.0) + Double(i) * 1.9) >= 0 ? 1.0 : -1.0
                let jitter = sin(t * (3.8 + feature.mid * 3.2) + Double(i) * 1.1)
                let cx = size.width * 0.5
                    + CGFloat(cos(orbit) * r * 1.1)
                    + CGFloat(zig * (5.0 + feature.energy * 9.0) + jitter * (2.0 + feature.energy * 3.0))
                let cy = size.height * 0.35
                    + CGFloat(sin(orbit * 1.3) * r * 0.5)
                    + CGFloat(zig * (2.0 + feature.pulse * 4.0))
                position = CGPoint(x: cx, y: cy)
                angle = orbit + .pi / 2 + zig * 0.18
            }

            drawBird(
                context: &context,
                center: position,
                angle: angle,
                size: birdSize,
                wingScale: wing,
                color: color
            )
        }
    }

    // MARK: - Other styles
    private func drawMinimalScene(context: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.52)
        let scale = min(size.width, size.height) * 0.42
        let shape = elephantOutline(trunkShift: sin(t * 0.9) * 0.02, earLift: 0)
            .applying(CGAffineTransform.identity.translatedBy(x: center.x, y: center.y).scaledBy(x: scale, y: scale))
        context.stroke(shape, with: .color(.white.opacity(0.92)), style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))
    }

    private func drawEmblemScene(context: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let g = Gradient(colors: [Color(white: 0.02), Color(white: 0.1), Color(white: 0.02)])
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(g, startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        let radius = min(size.width, size.height) * 0.31
        let outer = polygon(center: center, radius: radius, sides: 8, rotation: t * 0.03)
        let inner = polygon(center: center, radius: radius * 0.74, sides: 8, rotation: -t * 0.04)
        context.stroke(outer, with: .color(.white.opacity(0.28)), style: StrokeStyle(lineWidth: 1.2))
        context.stroke(inner, with: .color(.white.opacity(0.18)), style: StrokeStyle(lineWidth: 1.0))
        let elephant = elephantOutline(trunkShift: sin(t * 1.0) * 0.02, earLift: 0)
            .applying(CGAffineTransform.identity.translatedBy(x: center.x, y: center.y).scaledBy(x: radius * 1.25, y: radius * 1.25))
        context.stroke(elephant, with: .color(.white.opacity(0.86)), style: StrokeStyle(lineWidth: 1.4, lineJoin: .round))
    }

    // MARK: - Geometry
    private func elephantOutline(trunkShift: Double, earLift: Double) -> Path {
        let pts: [CGPoint] = [
            CGPoint(x: -0.16, y: -0.42),                              // forehead left
            CGPoint(x: -0.44, y: -0.58 - earLift * 0.6),              // ear attachment top
            CGPoint(x: -0.74, y: -0.52 - earLift * 1.0),              // ear top outer
            CGPoint(x: -0.9, y: -0.24 - earLift * 0.7),               // ear outer
            CGPoint(x: -0.84, y: 0.09 + earLift * 0.28),              // ear lower outer
            CGPoint(x: -0.64, y: 0.23 + earLift * 0.18),              // ear lower inner
            CGPoint(x: -0.4, y: 0.2 + earLift * 0.08),                // ear inner
            CGPoint(x: -0.24, y: 0.03),                               // cheek
            CGPoint(x: -0.11, y: -0.145),                             // trunk bridge left
            CGPoint(x: -0.05 + trunkShift * 0.14, y: 0.2),
            CGPoint(x: -0.04 + trunkShift * 0.8, y: 0.48),
            CGPoint(x: -0.14 + trunkShift * 0.75, y: 0.78),
            CGPoint(x: 0.0, y: 0.82),
            CGPoint(x: 0.14 + trunkShift * 0.55, y: 0.78),
            CGPoint(x: 0.04 + trunkShift * 0.62, y: 0.48),
            CGPoint(x: 0.05 + trunkShift * 0.2, y: 0.2),
            CGPoint(x: 0.11, y: -0.145),                              // trunk bridge right
            CGPoint(x: 0.24, y: 0.03),                                // cheek
            CGPoint(x: 0.4, y: 0.2 + earLift * 0.08),                 // ear inner
            CGPoint(x: 0.64, y: 0.23 + earLift * 0.18),               // ear lower inner
            CGPoint(x: 0.84, y: 0.09 + earLift * 0.28),               // ear lower outer
            CGPoint(x: 0.9, y: -0.24 - earLift * 0.7),                // ear outer
            CGPoint(x: 0.74, y: -0.52 - earLift * 1.0),               // ear top outer
            CGPoint(x: 0.44, y: -0.58 - earLift * 0.6),               // ear attachment top
            CGPoint(x: 0.16, y: -0.42),                               // forehead right
            CGPoint(x: 0.0, y: -0.58)                                 // crown
        ]
        return pathFrom(points: pts)
    }

    private func elephantFacets(trunkShift: Double, earLift: Double) -> [[CGPoint]] {
        let p: [CGPoint] = [
            CGPoint(x: 0.0, y: -0.58),                           // 0 crown
            CGPoint(x: -0.16, y: -0.42),                         // 1 foreheadL
            CGPoint(x: 0.16, y: -0.42),                          // 2 foreheadR
            CGPoint(x: -0.44, y: -0.58 - earLift * 0.6),         // 3 earAttachTopL
            CGPoint(x: -0.74, y: -0.52 - earLift * 1.0),         // 4 earTopOuterL
            CGPoint(x: -0.9, y: -0.24 - earLift * 0.7),          // 5 earMidOuterL
            CGPoint(x: -0.84, y: 0.09 + earLift * 0.28),         // 6 earLowOuterL
            CGPoint(x: -0.64, y: 0.23 + earLift * 0.18),         // 7 earLowInnerL
            CGPoint(x: -0.4, y: 0.2 + earLift * 0.08),           // 8 earInnerL
            CGPoint(x: -0.24, y: 0.03),                          // 9 cheekL
            CGPoint(x: -0.11, y: -0.145),                        // 10 bridgeL
            CGPoint(x: 0.11, y: -0.145),                         // 11 bridgeR
            CGPoint(x: 0.24, y: 0.03),                           // 12 cheekR
            CGPoint(x: 0.4, y: 0.2 + earLift * 0.08),            // 13 earInnerR
            CGPoint(x: 0.64, y: 0.23 + earLift * 0.18),          // 14 earLowInnerR
            CGPoint(x: 0.84, y: 0.09 + earLift * 0.28),          // 15 earLowOuterR
            CGPoint(x: 0.9, y: -0.24 - earLift * 0.7),           // 16 earMidOuterR
            CGPoint(x: 0.74, y: -0.52 - earLift * 1.0),          // 17 earTopOuterR
            CGPoint(x: 0.44, y: -0.58 - earLift * 0.6),          // 18 earAttachTopR
            CGPoint(x: -0.05 + trunkShift * 0.14, y: 0.2),       // 19 trunk1L
            CGPoint(x: -0.04 + trunkShift * 0.8, y: 0.48),       // 20 trunk2L
            CGPoint(x: -0.14 + trunkShift * 0.75, y: 0.78),      // 21 trunkTipL
            CGPoint(x: 0.0, y: 0.84),                            // 22 trunkTipM
            CGPoint(x: 0.14 + trunkShift * 0.55, y: 0.78),       // 23 trunkTipR
            CGPoint(x: 0.04 + trunkShift * 0.62, y: 0.48),       // 24 trunk2R
            CGPoint(x: 0.05 + trunkShift * 0.2, y: 0.2)          // 25 trunk1R
        ]
        let tri: [[Int]] = [
            [0, 1, 2],
            [0, 3, 1], [3, 4, 1], [4, 5, 1], [5, 6, 8], [6, 7, 8], [1, 5, 8], [1, 8, 9], [1, 9, 10],
            [0, 2, 18], [18, 2, 17], [17, 2, 16], [16, 2, 13], [16, 15, 13], [15, 14, 13], [2, 12, 13], [2, 11, 12],
            [10, 11, 19], [11, 25, 19], [9, 10, 19], [8, 9, 19],
            [19, 20, 25], [20, 24, 25], [20, 21, 24], [21, 22, 23], [20, 21, 23], [20, 23, 24], [11, 12, 25], [12, 13, 25]
        ]
        return tri.map { [p[$0[0]], p[$0[1]], p[$0[2]]] }
    }

    // MARK: - Helpers
    private func pathFrom(points: [CGPoint]) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: first)
        for pt in points.dropFirst() { p.addLine(to: pt) }
        p.closeSubpath()
        return p
    }

    private func polygon(center: CGPoint, radius: Double, sides: Int, rotation: Double) -> Path {
        var p = Path()
        let n = max(3, sides)
        for i in 0..<n {
            let a = rotation + (Double(i) / Double(n)) * .pi * 2
            let pt = CGPoint(x: center.x + cos(a) * radius, y: center.y + sin(a) * radius)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    private func quadratic(start: CGPoint, control: CGPoint, end: CGPoint) -> Path {
        var p = Path()
        p.move(to: start)
        p.addQuadCurve(to: end, control: control)
        return p
    }

    private func quadPoint(a: CGPoint, b: CGPoint, c: CGPoint, t: Double) -> CGPoint {
        let mt = CGFloat(1 - t)
        let tt = CGFloat(t)
        let x = mt * mt * a.x + 2 * mt * tt * b.x + tt * tt * c.x
        let y = mt * mt * a.y + 2 * mt * tt * b.y + tt * tt * c.y
        return CGPoint(x: x, y: y)
    }

    private func drawBird(
        context: inout GraphicsContext,
        center: CGPoint,
        angle: Double,
        size: Double,
        wingScale: Double,
        color: Color
    ) {
        let body = pathFrom(points: [
            CGPoint(x: -size * 0.23, y: -size * 0.08),
            CGPoint(x: size * 0.02, y: -size * 0.2),
            CGPoint(x: size * 0.24, y: -size * 0.04),
            CGPoint(x: size * 0.22, y: size * 0.16),
            CGPoint(x: 0, y: size * 0.24),
            CGPoint(x: -size * 0.22, y: size * 0.1)
        ])
        let wingL = pathFrom(points: [
            CGPoint(x: -size * 0.05, y: -size * 0.02),
            CGPoint(x: -size * (0.58 * wingScale), y: -size * (0.3 * wingScale)),
            CGPoint(x: -size * (0.34 * wingScale), y: size * 0.16)
        ])
        let wingR = pathFrom(points: [
            CGPoint(x: size * 0.03, y: -size * 0.02),
            CGPoint(x: size * (0.58 * wingScale), y: -size * (0.3 * wingScale)),
            CGPoint(x: size * (0.34 * wingScale), y: size * 0.16)
        ])
        let beak = pathFrom(points: [
            CGPoint(x: size * 0.26, y: size * 0.01),
            CGPoint(x: size * 0.4, y: size * 0.04),
            CGPoint(x: size * 0.26, y: size * 0.1)
        ])

        let rotate = CGAffineTransform(rotationAngle: CGFloat(angle))
        let translate = CGAffineTransform(translationX: center.x, y: center.y)
        let tx = rotate.concatenating(translate)

        for part in [wingL, wingR] {
            let p = part.applying(tx)
            context.fill(p, with: .color(color.opacity(0.8)))
            context.stroke(p, with: .color(.black.opacity(0.35)), style: StrokeStyle(lineWidth: 0.9, lineJoin: .round))
        }
        let bodyP = body.applying(tx)
        context.fill(bodyP, with: .color(color))
        context.stroke(bodyP, with: .color(.black.opacity(0.45)), style: StrokeStyle(lineWidth: 1.0, lineJoin: .round))

        let beakP = beak.applying(tx)
        context.fill(beakP, with: .color(.white.opacity(0.88)))
        context.stroke(beakP, with: .color(.black.opacity(0.25)), style: StrokeStyle(lineWidth: 0.8))

        let eye = polygon(center: CGPoint(x: size * 0.11, y: -size * 0.02), radius: size * 0.045, sides: 5, rotation: .pi / 5)
            .applying(tx)
        context.fill(eye, with: .color(.black.opacity(0.92)))
    }

    private func pseudoNoise(seed: Double) -> Double {
        let x = sin(seed * 12.9898) * 43758.5453
        return x - floor(x)
    }

    private func clamp(_ value: Double, _ minValue: Double, _ maxValue: Double) -> Double {
        min(max(value, minValue), maxValue)
    }

    private func fract(_ value: Double) -> Double {
        value - floor(value)
    }
}
