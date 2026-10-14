// Project-owned roles; shadcn typography is a styling recipe, not this component API.
import type { HTMLAttributes } from "react"
export function Typography({className="",...props}:HTMLAttributes<HTMLDivElement>){return <div className={"typeset "+className} {...props}/>}
