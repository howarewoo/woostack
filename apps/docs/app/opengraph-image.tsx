import { ImageResponse } from "next/og";
import { WMark } from "@/components/brand";

export const alt = "WooStack logo";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default function Image() {
  return new ImageResponse(
    <div
      style={{
        width: "100%",
        height: "100%",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        position: "relative",
        backgroundColor: "#365BE8",
      }}
    >
      <svg
        width={1200}
        height={630}
        viewBox="0 0 1200 630"
        fill="none"
        style={{ position: "absolute", top: 0, left: 0 }}
      >
        <rect x={150} y={75} width={900} height={480} stroke="#849BFF" />
        <path
          d="M300 75v480M450 75v480M600 75v480M750 75v480M900 75v480M150 155h900M150 235h900M150 315h900M150 395h900M150 475h900"
          stroke="#849BFF"
          strokeOpacity={0.33}
        />
        <path
          d="M140 75h20M150 65v20M1040 75h20M1050 65v20M140 555h20M150 545v20M1040 555h20M1050 545v20"
          stroke="#C9D5FF"
          strokeWidth={2}
        />
      </svg>
      <WMark width={448} height={448} fill="#F4F6FA" style={{ position: "relative" }} />
    </div>,
    size,
  );
}
