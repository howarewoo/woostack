import { useState } from "react";
import {
  MessageScroller,
  MessageScrollerButton,
  MessageScrollerContent,
  MessageScrollerItem,
  MessageScrollerProvider,
  MessageScrollerViewport,
} from "@/components/ui/message-scroller";
import { Button } from "@/components/ui/button";
export default function MessageScrollerExample() {
  const [count, setCount] = useState(20);
  return (
    <MessageScrollerProvider>
      <div className="relative">
        <MessageScroller className="h-72">
          <MessageScrollerViewport>
            <MessageScrollerContent>
              {Array.from({ length: count }, (_, index) => (
                <MessageScrollerItem key={index} className="rounded border p-4">
                  Message {index + 1}: a local conversation example.
                </MessageScrollerItem>
              ))}
            </MessageScrollerContent>
          </MessageScrollerViewport>
          <MessageScrollerButton />
        </MessageScroller>
        <Button onClick={() => setCount(count + 1)}>Add message</Button>
      </div>
    </MessageScrollerProvider>
  );
}
