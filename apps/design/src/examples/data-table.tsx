import { DataTable } from "@/catalog/data-table"
const data=Array.from({length:12},(_,index)=>({name:`Item ${index+1}`,quantity:index+2}))
export default function DataTableExample(){return <DataTable data={data} columns={[{accessorKey:"name",header:"Name"},{accessorKey:"quantity",header:"Quantity"}]}/>}
