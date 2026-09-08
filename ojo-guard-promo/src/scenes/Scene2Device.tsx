import React from "react";
import {
  AbsoluteFill,
  Img,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { colors } from "../theme";
import { fontFamily, monoFontFamily } from "../fonts";
import { StatusTag } from "../components/StatusTag";

// Screen rect measured on the source watch-hero.png (1000x795 canvas).
const SCREEN = {
  left: 30,
  top: 18.24,
  width: 34.5,
  height: 55.97,
};

export const Scene2Device: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const deviceScale = spring({
    frame,
    fps,
    config: { damping: 200, mass: 0.6 },
    durationInFrames: 30,
  });
  const deviceOpacity = interpolate(frame, [0, 18], [0, 1], {
    extrapolateRight: "clamp",
  });

  const glowOpacity = interpolate(frame, [15, 40], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const uiOpacity = interpolate(frame, [45, 68], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const pulseDash = interpolate(frame % 90, [0, 90], [0, 240]);

  const tagOpacity = interpolate(frame, [82, 100], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const captionOpacity = interpolate(frame, [100, 122], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const captionY = interpolate(frame, [100, 122], [14, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill style={{ backgroundColor: colors.bgObsidian }}>
      {/* ambient warm bounce, off-center, restrained */}
      <AbsoluteFill
        style={{
          background:
            "radial-gradient(60% 42% at 50% 34%, rgba(244,160,80,0.16) 0%, rgba(10,10,11,0) 70%)",
          opacity: glowOpacity,
        }}
      />

      <AbsoluteFill
        style={{ justifyContent: "flex-start", alignItems: "center", paddingTop: 210 }}
      >
        <div
          style={{
            fontFamily: monoFontFamily,
            fontSize: 16,
            letterSpacing: 3,
            color: colors.statusBlueGray,
            textTransform: "uppercase",
            opacity: deviceOpacity,
            marginBottom: 40,
          }}
        >
          el reloj
        </div>

        <div
          style={{
            position: "relative",
            width: 640,
            aspectRatio: "1000 / 795",
            opacity: deviceOpacity,
            transform: `scale(${0.9 + deviceScale * 0.1})`,
          }}
        >
          <Img
            src={staticFile("watch-hero.png")}
            style={{ width: "100%", height: "100%", objectFit: "contain" }}
          />

          {/* our own on-screen UI, replacing the OEM graphic that was masked out */}
          <div
            style={{
              position: "absolute",
              left: `${SCREEN.left}%`,
              top: `${SCREEN.top}%`,
              width: `${SCREEN.width}%`,
              height: `${SCREEN.height}%`,
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
              justifyContent: "center",
              opacity: uiOpacity,
            }}
          >
            <svg width="19%" viewBox="0 0 32 29" style={{ marginBottom: "6%" }}>
              <path
                d="M16 28.5C8 22.8 1 17 1 9.8 1 4.9 4.9 1 9.7 1c2.8 0 5.4 1.4 6.9 3.6C18.1 2.4 20.7 1 23.5 1 28.3 1 32.2 4.9 32.2 9.8 32.2 17 25.2 22.8 17.2 28.5z"
                fill="none"
                stroke={colors.accentAmber}
                strokeWidth="2"
              />
            </svg>
            <svg width="70%" height="14%" viewBox="0 0 240 40" style={{ overflow: "visible" }}>
              <polyline
                points="0,20 40,20 55,4 70,36 85,20 240,20"
                fill="none"
                stroke={colors.accentAmber}
                strokeWidth="2.5"
                strokeLinejoin="round"
                strokeLinecap="round"
                strokeDasharray="240"
                strokeDashoffset={240 - pulseDash}
                opacity={0.9}
              />
            </svg>
            <div
              style={{
                fontFamily: monoFontFamily,
                fontSize: 13,
                letterSpacing: 1.5,
                color: colors.uiIce,
                marginTop: "8%",
                opacity: 0.85,
              }}
            >
              monitoreo
            </div>
          </div>
        </div>

        <div style={{ marginTop: 56, opacity: tagOpacity }}>
          <StatusTag tier="nucleo" />
        </div>

        <div
          style={{
            marginTop: 26,
            padding: "0 110px",
            textAlign: "center",
            opacity: captionOpacity,
            transform: `translateY(${captionY}px)`,
          }}
        >
          <div
            style={{
              fontFamily,
              fontWeight: 400,
              fontSize: 27,
              lineHeight: 1.45,
              color: colors.inkIvory,
            }}
          >
            detección de caídas: implementada en código,
            <br />
            todavía no probada en cada caso real.
          </div>
          <div
            style={{
              fontFamily,
              fontWeight: 300,
              fontSize: 19,
              lineHeight: 1.4,
              color: colors.uiIce,
              marginTop: 14,
              opacity: 0.85,
            }}
          >
            built into the code. not yet proven on every real fall.
          </div>
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
