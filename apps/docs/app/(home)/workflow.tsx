"use client";

import { useRef, useState, type KeyboardEvent } from "react";
import styles from "./home.module.css";

const steps = [
  {
    name: "Inspect",
    number: "01 / CONTEXT",
    status: "Bounded scope",
    title: "Start with the repository.",
    copy: "Inspect project guidance and the relevant code before making the agreed change.",
    key: "Input",
    value: "Agreed change + repository context",
  },
  {
    name: "Implement",
    number: "02 / CHANGE",
    status: "Agreed work",
    title: "Make the bounded change.",
    copy: "Implement the authorized change within the agreed scope and the project’s existing conventions.",
    key: "Scope",
    value: "The agreed change, with project guidance",
  },
  {
    name: "Verify",
    number: "03 / EVIDENCE",
    status: "Human review",
    title: "Show how it was verified.",
    copy: "Run appropriate checks and explain the result, including what remains unverified. Deliver a draft PR when requested.",
    key: "Handoff",
    value: "Change summary + verification evidence",
  },
];

export function Workflow() {
  const [selected, setSelected] = useState(0);
  const tabs = useRef<(HTMLButtonElement | null)[]>([]);
  const step = steps[selected];

  function navigate(event: KeyboardEvent<HTMLButtonElement>, index: number) {
    let next: number;
    switch (event.key) {
      case "ArrowRight":
        next = (index + 1) % steps.length;
        break;
      case "ArrowLeft":
        next = (index + steps.length - 1) % steps.length;
        break;
      case "Home":
        next = 0;
        break;
      case "End":
        next = steps.length - 1;
        break;
      default:
        return;
    }
    event.preventDefault();
    setSelected(next);
    tabs.current[next]?.focus();
  }

  return (
    <div className={styles.workbench}>
      <div className={styles.workbenchHeader}>
        <code>/woostack-execute</code>
        <span className={styles.status}>Illustrative</span>
      </div>
      <blockquote>“Implement this agreed change and show me how you verified it.”</blockquote>
      <div role="tablist" aria-label="Explore the Execute example" className={styles.tabs}>
        {steps.map((item, index) => (
          <button
            key={item.name}
            ref={(node) => {
              tabs.current[index] = node;
            }}
            type="button"
            role="tab"
            id={`workflow-tab-${index}`}
            aria-controls="workflow-panel"
            aria-selected={selected === index}
            tabIndex={selected === index ? 0 : -1}
            onClick={() => setSelected(index)}
            onKeyDown={(event) => navigate(event, index)}
          >
            {item.name}
          </button>
        ))}
      </div>
      <div
        id="workflow-panel"
        role="tabpanel"
        aria-labelledby={`workflow-tab-${selected}`}
        tabIndex={0}
        className={styles.panel}
      >
        <div className={styles.stepLabel}>
          <span>{step.number}</span>
          <span className={`${styles.status} ${styles.neutral}`}>{step.status}</span>
        </div>
        <h3>{step.title}</h3>
        <p>{step.copy}</p>
        <div className={styles.record}>
          <span>{step.key}</span>
          <code>{step.value}</code>
        </div>
      </div>
      <p className={styles.note}>Workflow illustration. No agent runs here.</p>
    </div>
  );
}
