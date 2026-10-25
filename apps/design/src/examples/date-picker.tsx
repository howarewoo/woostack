import { useState } from "react";
import { DatePicker } from "@/catalog/date-picker";
export default function DatePickerExample() {
  const [date, setDate] = useState<Date>();
  return (
    <div className="space-y-4">
      <DatePicker value={date} onChange={setDate} />
      <p role="status">{date?.toLocaleDateString() ?? "No date selected"}</p>
    </div>
  );
}
