import { DirectionProvider } from "@/components/ui/direction"
import { Button } from "@/components/ui/button"
export default function DirectionExample() { return <div className="grid gap-4">{(["ltr","rtl"] as const).map(direction => <DirectionProvider key={direction} direction={direction}><div dir={direction} className="flex gap-2 rounded border p-4"><Button>First</Button><Button variant="outline">Second</Button><span>{direction}</span></div></DirectionProvider>)}</div> }
