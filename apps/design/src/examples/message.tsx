import { Message,MessageAvatar,MessageContent,MessageHeader,MessageFooter } from "@/components/ui/message"
import { Avatar,AvatarFallback } from "@/components/ui/avatar"
import { Bubble,BubbleContent } from "@/components/ui/bubble"
export default function MessageExample(){return <Message><MessageAvatar><Avatar><AvatarFallback>AL</AvatarFallback></Avatar></MessageAvatar><MessageContent><MessageHeader>Alex · just now</MessageHeader><Bubble><BubbleContent>The draft is ready for review.</BubbleContent></Bubble><MessageFooter>Delivered</MessageFooter></MessageContent></Message>}
