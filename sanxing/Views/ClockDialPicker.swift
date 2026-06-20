// Views/ClockDialPicker.swift — 24 小时表盘（仿健康 App 睡眠时段）：拖两个把手改 start/end
import SwiftUI

struct ClockDialPicker: View {
    @Binding var start: Date
    @Binding var end: Date
    var color: Color
    var startIcon: String = "bed.double.fill"
    var endIcon: String = "flag.fill"

    private let ringWidth: CGFloat = 30
    private let snapMinutes = 5

    private enum Knob { case start, end }
    @State private var active: Knob?
    // 触摸命中带（圆环）比可见环略宽，便于抓取
    private var touchBand: CGFloat { ringWidth + 16 }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let c = CGPoint(x: geo.size.width / 2, y: side / 2)
            let r = (side - ringWidth) / 2
            let labelR = r - ringWidth / 2 - 16
            ZStack {
                // 轨道
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: ringWidth)
                    .frame(width: r * 2, height: r * 2)
                    .position(c)

                // 选中弧（从 start 顺时针铺到 end）——单段 trim 旋转，避免跨 0 接缝
                Circle()
                    .trim(from: 0, to: durationHours / 24)
                    .stroke(color, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                    .rotationEffect(.degrees(hours(of: start) / 24 * 360 - 90))
                    .frame(width: r * 2, height: r * 2)
                    .position(c)

                // 整点刻度数字：0/6/12/18 高亮加粗，其余次要
                ForEach(Array(stride(from: 0, to: 24, by: 2)), id: \.self) { h in
                    let major = h % 6 == 0
                    Text("\(h)")
                        .font(major ? .headline : .caption2).monospacedDigit()
                        .fontWeight(.regular)
                        .foregroundStyle(major ? Color.primary : .secondary)
                        .position(point(Double(h), center: c, radius: labelR))
                }
                // 午夜 ✨ / 正午 ☀️（同健康 App）
                Image(systemName: "sparkles").font(.footnote).foregroundStyle(.cyan)
                    .position(point(0, center: c, radius: labelR - 30))
                Image(systemName: "sun.max.fill").font(.footnote).foregroundStyle(.yellow)
                    .position(point(12, center: c, radius: labelR - 30))

                // 中心时长
                VStack(spacing: 2) {
                    Text(formatDuration(max(0, end.timeIntervalSince(start)))).font(.headline)
                    Text("时长").font(.caption2).foregroundStyle(.secondary)
                }
                .position(c)

                // 把手
                knob(startIcon).position(point(hours(of: start), center: c, radius: r))
                knob(endIcon).position(point(hours(of: start) + durationHours, center: c, radius: r))
            }
            // 只把「圆环带」作为命中区：点中心/外侧不拦截 → 交给外层 ScrollView 滚动，避免误触
            .contentShape(RingShape(radius: r, width: touchBand))
            .highPriorityGesture(drag(center: c, radius: r))
        }
        .frame(height: 240)
    }

    private func knob(_ icon: String) -> some View {
        ZStack {
            Circle().fill(Color(.systemBackground))
                .frame(width: ringWidth - 4, height: ringWidth - 4)
                .shadow(color: .black.opacity(0.2), radius: 1.5)
            Image(systemName: icon).font(.caption).foregroundStyle(color)
        }
    }

    // MARK: - 几何

    // 时长（小时），绘制时上限 24
    private var durationHours: Double { min(24, max(0, end.timeIntervalSince(start) / 3600)) }

    // 一天内的时刻（小时，含分钟小数）
    private func hours(of d: Date) -> Double {
        let comp = Calendar.current.dateComponents([.hour, .minute], from: d)
        return Double(comp.hour ?? 0) + Double(comp.minute ?? 0) / 60
    }

    // 时刻 → 表盘坐标（0 在正上方，顺时针）
    private func point(_ t: Double, center c: CGPoint, radius r: CGFloat) -> CGPoint {
        let a = t / 24 * 2 * .pi
        return CGPoint(x: c.x + r * CGFloat(sin(a)), y: c.y - r * CGFloat(cos(a)))
    }

    // 触点 → 时刻
    private func hours(at p: CGPoint, center c: CGPoint) -> Double {
        var a = atan2(Double(p.x - c.x), Double(c.y - p.y))   // 0 在上方，顺时针
        if a < 0 { a += 2 * .pi }
        return a / (2 * .pi) * 24
    }

    private func snap(_ h: Double) -> Double {
        let dayMin = 24.0 * 60
        var m = (h * 60 / Double(snapMinutes)).rounded() * Double(snapMinutes)
        m = m.truncatingRemainder(dividingBy: dayMin)
        if m < 0 { m += dayMin }
        return m / 60
    }

    // 两个时刻的圆周最近距离（小时）
    private func circDist(_ a: Double, _ b: Double) -> Double {
        let d = abs(a.truncatingRemainder(dividingBy: 24) - b.truncatingRemainder(dividingBy: 24))
        return min(d, 24 - d)
    }

    // MARK: - 拖拽

    private func drag(center c: CGPoint, radius r: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                let th = snap(hours(at: v.location, center: c))
                if active == nil {
                    let ds = circDist(th, hours(of: start))
                    let de = circDist(th, hours(of: start) + durationHours)
                    active = ds <= de ? .start : .end
                }
                if active == .start { setStart(toHours: th) } else { setEnd(toHours: th) }
            }
            .onEnded { _ in active = nil }
    }

    // 拖开始：保持 end 不动，start 取 end 之前最近的该时刻（时长锁在 0…24h）
    private func setStart(toHours th: Double) {
        let day = Calendar.current.startOfDay(for: end)
        var cand = day.addingTimeInterval(th * 3600)
        while cand >= end { cand = cand.addingTimeInterval(-86400) }
        if end.timeIntervalSince(cand) > 86400 { cand = cand.addingTimeInterval(86400) }
        start = cand
    }

    // 拖结束：保持 start 不动，end 取 start 之后最近的该时刻（支持跨午夜，时长锁在 0…24h）
    private func setEnd(toHours th: Double) {
        let day = Calendar.current.startOfDay(for: start)
        var cand = day.addingTimeInterval(th * 3600)
        while cand <= start { cand = cand.addingTimeInterval(86400) }
        if cand.timeIntervalSince(start) > 86400 { cand = cand.addingTimeInterval(-86400) }
        end = cand
    }
}

// 圆环命中形状：外圆 + 反向内圆 → 填充出环带，只让环带区域参与命中
private struct RingShape: Shape {
    var radius: CGFloat   // 环中线半径
    var width: CGFloat    // 环带宽度

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var p = Path()
        p.addArc(center: c, radius: radius + width / 2, startAngle: .zero, endAngle: .degrees(360), clockwise: false)
        p.addArc(center: c, radius: max(0, radius - width / 2), startAngle: .degrees(360), endAngle: .zero, clockwise: true)
        return p
    }
}
