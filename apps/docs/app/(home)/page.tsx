import Link from "next/link";
import { ArrowRight, ArrowUpRight } from "lucide-react";
import { Brand, WMark } from "@/components/brand";
import { Workflow } from "./workflow";
import styles from "./home.module.css";

export default function HomePage() {
  return (
    <div className={styles.page}>
      <section className={styles.hero} aria-labelledby="main-content">
        <div>
          <h1 id="main-content" tabIndex={-1}>
            Give your
            <br />
            coding agent
            <br />
            <em>a way to work.</em>
          </h1>
          <p className={styles.intro}>
            Skills for AI coding assistants to refine a goal, plan the work, and make reviewable
            changes, grounded in your repository and guided by your decisions.
          </p>
          <div className={styles.actions}>
            <Link href="/docs/getting-started" className={`${styles.button} ${styles.primary}`}>
              Get started <ArrowRight aria-hidden="true" size={18} />
            </Link>
            <a
              href="https://github.com/howarewoo/woostack"
              className={`${styles.button} ${styles.secondary}`}
            >
              View on GitHub <ArrowUpRight aria-hidden="true" size={18} />
            </a>
          </div>
        </div>
        <div className={styles.construction} aria-hidden="true">
          <div className={styles.grid} />
          <span className={`${styles.cross} ${styles.tl}`} />
          <span className={`${styles.cross} ${styles.tr}`} />
          <span className={`${styles.cross} ${styles.bl}`} />
          <span className={`${styles.cross} ${styles.br}`} />
          <WMark className={styles.mark} />
        </div>
      </section>
      <div className={styles.install}>
        <div>
          <span className={styles.installLabel}>Install the skills</span>
          <code>pnpx skills add howarewoo/woostack</code>
        </div>
        <p>
          Install the collection or just the skills you need.
          <br />
          Requires Node.js and pnpm.
        </p>
      </div>
      <section className={styles.workflow} id="workflow" aria-labelledby="workflow-title">
        <div className={styles.workflowIntro}>
          <h2 id="workflow-title">
            Deliberate work.
            <br />
            Reviewable changes.
          </h2>
          <p>
            Choose a skill for your task. This Execute example shows a bounded change, from
            repository context to verification.
          </p>
          <p className={styles.muted}>
            Planning does not start implementation. You authorize delivery; merging remains your
            decision.
          </p>
          <Link className={styles.textLink} href="/docs/skills/woostack-execute">
            Read the Execute skill <ArrowRight size={18} aria-hidden="true" />
          </Link>
        </div>
        <Workflow />
      </section>
      <footer className={styles.footer}>
        <Link href="/" aria-label="WooStack home">
          <Brand />
        </Link>
        <nav aria-label="Footer">
          <Link href="/docs">Documentation</Link>
          <a href="https://github.com/howarewoo/woostack">GitHub</a>
        </nav>
      </footer>
    </div>
  );
}
