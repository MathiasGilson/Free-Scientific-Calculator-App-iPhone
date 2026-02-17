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
    landmark: [
        { type: "path", d: "M3 22h18" },
        { type: "path", d: "M6 18v-7" },
        { type: "path", d: "M10 18v-7" },
        { type: "path", d: "M14 18v-7" },
        { type: "path", d: "M18 18v-7" },
        { type: "path", d: "M12 2 3 9h18Z" },
    ],
    calculator: [
        { type: "rect", x: 4, y: 2, width: 16, height: 20, rx: 2 },
        { type: "path", d: "M8 6h8" },
        { type: "path", d: "M16 14v4" },
        { type: "path", d: "M16 10h.01" },
        { type: "path", d: "M12 10h.01" },
        { type: "path", d: "M8 10h.01" },
        { type: "path", d: "M12 14h.01" },
        { type: "path", d: "M8 14h.01" },
        { type: "path", d: "M12 18h.01" },
        { type: "path", d: "M8 18h.01" },
    ],
    "dollar-sign": [
        { type: "path", d: "M12 2v20" },
        { type: "path", d: "M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6" },
    ],
    "layout-grid": [
        { type: "rect", x: 3, y: 3, width: 7, height: 7, rx: 1 },
        { type: "rect", x: 14, y: 3, width: 7, height: 7, rx: 1 },
        { type: "rect", x: 14, y: 14, width: 7, height: 7, rx: 1 },
        { type: "rect", x: 3, y: 14, width: 7, height: 7, rx: 1 },
    ],
    "chevron-left": [
        { type: "path", d: "m15 18-6-6 6-6" },
    ],
    bookmark: [
        { type: "path", d: "m19 21-7-4-7 4V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v16z" },
    ],
    triangle: [
        { type: "path", d: "M13.73 4a2 2 0 0 0-3.46 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z" },
    ],
    flame: [
        { type: "path", d: "M12 3q1 4 4 6.5t3 5.5a1 1 0 0 1-14 0 5 5 0 0 1 1-3 1 1 0 0 0 5 0c0-2-1.5-3-1.5-5q0-2 2.5-4" },
    ],
    zap: [
        { type: "path", d: "M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z" },
    ],
    fuel: [
        { type: "path", d: "M14 13h2a2 2 0 0 1 2 2v2a2 2 0 0 0 4 0v-6.998a2 2 0 0 0-.59-1.42L18 5" },
        { type: "path", d: "M14 21V5a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v16" },
        { type: "path", d: "M2 21h13" },
        { type: "path", d: "M3 9h11" },
    ],
    "arrow-down-to-line": [
        { type: "path", d: "M12 17V3" },
        { type: "path", d: "m6 11 6 6 6-6" },
        { type: "path", d: "M19 21H5" },
    ],
    move: [
        { type: "path", d: "M12 2v20" },
        { type: "path", d: "m15 19-3 3-3-3" },
        { type: "path", d: "m19 9 3 3-3 3" },
        { type: "path", d: "M2 12h20" },
        { type: "path", d: "m5 9-3 3 3 3" },
        { type: "path", d: "m9 5 3-3 3 3" },
    ],
    "bookmark-filled": [
        { type: "path", d: "m19 21-7-4-7 4V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v16z", fill: "currentColor" },
    ],
    x: [
        { type: "path", d: "M18 6 6 18" },
        { type: "path", d: "m6 6 12 12" },
    ],
    "trash-2": [
        { type: "path", d: "M3 6h18" },
        { type: "path", d: "M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6" },
        { type: "path", d: "M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2" },
        { type: "path", d: "M10 11v6" },
        { type: "path", d: "M14 11v6" },
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
