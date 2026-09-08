import React from "react";
import { useCurrentFrame } from "remotion";
import { colors } from "../theme";
import { monoFontFamily } from "../fonts";

type Tier = "nucleo" | "prototipo" | "vision";

const tierConfig: Record<Tier, { label: string; color: string }> = {
  nucleo: { label: "NÚCLEO · EN VALIDACIÓN", color: colors.accentAmber },
  prototipo: { label: "PROTOTIPO", color: colors.uiIce },
  vision: { label: "VISIÓN", color: colors.statusBlueGray },
};

export const StatusTag: React.FC<{ tier: Tier; opacity?: number }> = ({
  tier,
  opacity = 1,
}) => {
  const frame = useCurrentFrame();
  const { label, color } = tierConfig[tier];
  // slow pulse, per brand spec ("solid line, slow pulse")
  const pulse = 0.65 + 0.35 * Math.sin(frame / 18);

  return (
    <div
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: 8,
        opacity,
      }}
    >
      <div
        style={{
          width: 6,
          height: 6,
          borderRadius: "50%",
          background: color,
          opacity: tier === "nucleo" ? pulse : 1,
          boxShadow: tier === "nucleo" ? `0 0 8px ${color}` : "none",
        }}
      />
      <span
        style={{
          fontFamily: monoFontFamily,
          fontSize: 15,
          letterSpacing: 1.5,
          color,
          fontWeight: 500,
        }}
      >
        {label}
      </span>
    </div>
  );
};
