import React from "react"
import Svg, { Path, Circle, Ellipse, Rect } from "react-native-svg"

type El =
    | { type: "path"; d: string; fill?: string }
    | { type: "circle"; cx: number; cy: number; r: number; fill?: string }
    | { type: "ellipse"; cx: number; cy: number; rx: number; ry: number }
    | { type: "rect"; x: number; y: number; width: number; height: number; rx?: number }

const icons: Record<string, El[]> = {
    ruler: [
        { type: "path", d: "M21.3 15.3a2.4 2.4 0 0 1 0 3.4l-2.6 2.6a2.4 2.4 0 0 1-3.4 0L2.7 8.7a2.41 2.41 0 0 1 0-3.4l2.6-2.6a2.41 2.41 0 0 1 3.4 0Z" },
        { type: "path", d: "m14.5 12.5 2-2" },
        { type: "path", d: "m11.5 9.5 2-2" },
        { type: "path", d: "m8.5 6.5 2-2" },
        { type: "path", d: "m17.5 15.5 2-2" },
    ],
    "grid-2x2": [
        { type: "rect", x: 3, y: 3, width: 18, height: 18, rx: 2 },
        { type: "path", d: "M12 3v18" },
        { type: "path", d: "M3 12h18" },
    ],
    weight: [
        { type: "circle", cx: 12, cy: 5, r: 3 },
        { type: "path", d: "M6.5 8a2 2 0 0 0-1.905 1.46L2.1 18.5A2 2 0 0 0 4 21h16a2 2 0 0 0 1.925-2.54L19.4 9.5A2 2 0 0 0 17.48 8Z" },
    ],
    "flask-conical": [
        { type: "path", d: "M14 2v6a2 2 0 0 0 .245.96l5.51 10.08A2 2 0 0 1 18 22H6a2 2 0 0 1-1.755-2.96l5.51-10.08A2 2 0 0 0 10 8V2" },
        { type: "path", d: "M6.453 15h11.094" },
        { type: "path", d: "M8.5 2h7" },
    ],
    gauge: [
        { type: "path", d: "m12 14 4-4" },
        { type: "path", d: "M3.34 19a10 10 0 1 1 17.32 0" },
    ],
    thermometer: [
        { type: "path", d: "M14 4v10.54a4 4 0 1 1-4 0V4a2 2 0 0 1 4 0Z" },
    ],
    clock: [
        { type: "circle", cx: 12, cy: 12, r: 10 },
        { type: "path", d: "M12 6v6l4 2" },
    ],
    database: [
        { type: "ellipse", cx: 12, cy: 5, rx: 9, ry: 3 },
        { type: "path", d: "M3 5V19A9 3 0 0 0 21 19V5" },
        { type: "path", d: "M3 12A9 3 0 0 0 21 12" },
    ],
    cake: [
        { type: "path", d: "M20 21v-8a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8" },
        { type: "path", d: "M4 16s.5-1 2-1 2.5 2 4 2 2.5-2 4-2 2.5 2 4 2 2-1 2-1" },
        { type: "path", d: "M2 21h20" },
        { type: "path", d: "M7 8v3" },
        { type: "path", d: "M12 8v3" },
        { type: "path", d: "M17 8v3" },
        { type: "path", d: "M7 4h.01" },
        { type: "path", d: "M12 4h.01" },
        { type: "path", d: "M17 4h.01" },
    ],
    "heart-pulse": [
        { type: "path", d: "M2 9.5a5.5 5.5 0 0 1 9.591-3.676.56.56 0 0 0 .818 0A5.49 5.49 0 0 1 22 9.5c0 2.29-1.5 4-3 5.5l-5.492 5.313a2 2 0 0 1-3 .019L5 15c-1.5-1.5-3-3.2-3-5.5" },
        { type: "path", d: "M3.22 13H9.5l.5-1 2 4.5 2-7 1.5 3.5h5.27" },
    ],
    calendar: [
        { type: "rect", x: 3, y: 4, width: 18, height: 18, rx: 2 },
        { type: "path", d: "M8 2v4" },
        { type: "path", d: "M16 2v4" },
        { type: "path", d: "M3 10h18" },
    ],
    tag: [
        { type: "path", d: "M12.586 2.586A2 2 0 0 0 11.172 2H4a2 2 0 0 0-2 2v7.172a2 2 0 0 0 .586 1.414l8.704 8.704a2.426 2.426 0 0 0 3.42 0l6.58-6.58a2.426 2.426 0 0 0 0-3.42z" },
        { type: "circle", cx: 7.5, cy: 7.5, r: 0.5, fill: "currentColor" },
    ],
    pin: [
        { type: "path", d: "M12 17v5" },
        { type: "path", d: "M9 11V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v7" },
        { type: "path", d: "M5 17h14" },
        { type: "path", d: "M9 11l-2.5 6h11L15 11" },
    ],
    "pin-filled": [
        { type: "path", d: "M12 17v5" },
        { type: "path", d: "M9 11V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v7", fill: "currentColor" },
        { type: "path", d: "M5 17h14" },
        { type: "path", d: "M9 11l-2.5 6h11L15 11", fill: "currentColor" },
    ],
}

type Props = {
    name: string
    size?: number
    color?: string
}

export default ({ name, size = 24, color = "white" }: Props) => {
    const elements = icons[name]
    if (!elements) return null

    return (
        <Svg width={size} height={size} viewBox="0 0 24 24" fill="none">
            {elements.map((el, i) => {
                const stroke = color
                const props = { key: i, stroke, strokeWidth: 2, strokeLinecap: "round" as const, strokeLinejoin: "round" as const }
                switch (el.type) {
                    case "path":
                        return <Path {...props} d={el.d} fill={el.fill === "currentColor" ? color : "none"} />
                    case "circle":
                        return <Circle {...props} cx={el.cx} cy={el.cy} r={el.r} fill={el.fill === "currentColor" ? color : "none"} />
                    case "ellipse":
                        return <Ellipse {...props} cx={el.cx} cy={el.cy} rx={el.rx} ry={el.ry} fill="none" />
                    case "rect":
                        return <Rect {...props} x={el.x} y={el.y} width={el.width} height={el.height} rx={el.rx} fill="none" />
                }
            })}
        </Svg>
    )
}
