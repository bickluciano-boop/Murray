import React from "react";
import { AbsoluteFill, Img, interpolate, staticFile, useCurrentFrame } from "remotion";
import { colors } from "../theme";
import { fontFamily, monoFontFamily } from "../fonts";

export const Scene1Lifestyle: React.FC = () => {
  const frame = useCurrentFrame();

  const bgOpacity = interpolate(frame, [0, 20], [0, 1], {
    extrapolateRight: "clamp",
  });
  const eyebrowOpacity = interpolate(frame, [12, 28], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const lineEsOpacity = interpolate(frame, [34, 54], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const lineEsY = interpolate(frame, [34, 54], [16, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const lineEnOpacity = interpolate(frame, [66, 86], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const lineEnY = interpolate(frame, [66, 86], [16, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill style={{ backgroundColor: colors.bgObsidian }}>
      <AbsoluteFill style={{ opacity: bgOpacity }}>
        <Img
          src={staticFile("lifestyle-scene.jpg")}
          style={{
            width: "100%",
            height: "100%",
            objectFit: "cover",
            objectPosition: "50% 20%",
            filter: "saturate(0.85) brightness(0.85)",
          }}
        />
        <AbsoluteFill
          style={{
            background:
              "linear-gradient(180deg, rgba(5,5,5,0.35) 0%, rgba(5,5,5,0.15) 38%, rgba(5,5,5,0.75) 78%, rgba(5,5,5,0.96) 100%)",
          }}
        />
      </AbsoluteFill>

      <AbsoluteFill
        style={{
          justifyContent: "flex-end",
          padding: "0 88px 160px 88px",
        }}
      >
        <div
          style={{
            fontFamily: monoFontFamily,
            fontSize: 17,
            letterSpacing: 3,
            color: colors.accentAmber,
            opacity: eyebrowOpacity,
            marginBottom: 28,
            textTransform: "uppercase",
          }}
        >
          ojo guard · presentación
        </div>
        <div
          style={{
            fontFamily,
            fontWeight: 400,
            fontSize: 52,
            lineHeight: 1.32,
            color: colors.inkIvory,
            opacity: lineEsOpacity,
            transform: `translateY(${lineEsY}px)`,
            marginBottom: 22,
          }}
        >
          no venimos a prometer
          <br />
          que nunca vas a estar solo.
        </div>
        <div
          style={{
            fontFamily,
            fontWeight: 300,
            fontSize: 30,
            lineHeight: 1.4,
            color: colors.uiIce,
            opacity: lineEnOpacity,
            transform: `translateY(${lineEnY}px)`,
          }}
        >
          we're not here to promise
          <br />
          you'll never be alone.
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
