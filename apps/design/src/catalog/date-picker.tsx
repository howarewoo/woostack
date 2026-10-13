// Owned controlled convenience composition, not an upstream component API.
import { useState } from "react"
import { format } from "date-fns"
import { CalendarIcon } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Calendar } from "@/components/ui/calendar"
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover"

export function DatePicker({ value, onChange }: {
  value?: Date
  onChange: (date: Date | undefined) => void
}) {
  const [open, setOpen] = useState(false)
  return <Popover open={open} onOpenChange={setOpen}>
    <PopoverTrigger render={<Button variant="outline" />}>
      <CalendarIcon />{value ? format(value, "PPP") : "Choose date"}
    </PopoverTrigger>
    <PopoverContent className="w-auto p-0">
      <Calendar mode="single" selected={value} onSelect={date => {
        onChange(date)
        setOpen(false)
      }} />
    </PopoverContent>
  </Popover>
}
