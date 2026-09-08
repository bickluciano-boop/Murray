import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { colors } from "../theme";
import { fontFamily, monoFontFamily } from "../fonts";

export const Scene3Closing: React.FC = () => {
  const frame = useCurrentFrame();

  const wordmarkOpacity = interpolate(frame, [0, 22], [0, 1], {
    extrapolateRight: "clamp",
  });
  const wordmarkY = interpolate(frame, [0, 22], [12, 0], {
    extrapolateRight: "clamp",
  });

  const taglineOpacity = interpolate(frame, [26, 46], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const lineOpacity = interpolate(frame, [56, 76], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill
      style={{
        backgroundColor: colors.bgObsidianDeep,
        justifyContent: "center",
        alignItems: "center",
      }}
    >
      <AbsoluteFill
        style={{
          background:
            "radial-gradient(48% 32% at 50% 46%, rgba(255,180,0,0.08) 0%, rgba(5,5,5,0) 70%)",
        }}
      />

      <div
        style={{
          fontFamily,
          fontWeight: 300,
          fontSize: 74,
          letterSpacing: 2,
          color: colors.uiIce,
          opacity: wordmarkOpacity,
          transform: `translateY(${wordmarkY}px)`,
        }}
      >
        ojo guard
      </div>

      <div
        style={{
          fontFamily,
          fontWeight: 400,
          fontSize: 30,
          color: colors.inkIvory,
          marginTop: 26,
          opacity: taglineOpacity,
          textAlign: "center",
        }}
      >
        algo cambió.
        <span style={{ color: colors.uiIce, fontWeight: 300 }}> / something changed.</span>
      </div>

      <div
        style={{
          fontFamily: monoFontFamily,
          fontSize: 15,
          letterSpacing: 1.5,
          color: colors.statusBlueGray,
          marginTop: 34,
          opacity: lineOpacity,
          textAlign: "center",
          textTransform: "uppercase",
        }}
      >
        seguimos construyendo, no imaginando.
      </div>
    </AbsoluteFill>
  );
};
