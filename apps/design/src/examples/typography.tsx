import { Typography } from "@/catalog/typography";
export default function TypographyExample() {
  return (
    <Typography>
      <h1>Clarity through hierarchy</h1>
      <h2>A neutral foundation</h2>
      <h3>Readable content</h3>
      <p>Use semantic headings, comfortable line lengths, and consistent spacing.</p>
      <p className="text-sm text-muted-foreground">Supporting metadata stays legible.</p>
      <blockquote>Design is the arrangement of useful information.</blockquote>
      <ul>
        <li>Body text</li>
        <li>Accessible labels</li>
      </ul>
      <code>const readable = true</code>
    </Typography>
  );
}
