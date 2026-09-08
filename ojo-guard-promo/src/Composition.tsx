import { AbsoluteFill, Composition, Sequence } from "remotion";
import { Scene1Lifestyle } from "./scenes/Scene1Lifestyle";
import { Scene2Device } from "./scenes/Scene2Device";
import { Scene3Closing } from "./scenes/Scene3Closing";
import { colors } from "./theme";

const FPS = 30;
const SCENE_1 = 150; // 5s
const SCENE_2 = 190; // ~6.3s
const SCENE_3 = 120; // 4s
const DURATION = SCENE_1 + SCENE_2 + SCENE_3;

export const MyComposition = () => {
  return (
    <Composition
      id="OjoGuardPromo"
      component={OjoGuardPromo}
      durationInFrames={DURATION}
      fps={FPS}
      width={1080}
      height={1920}
    />
  );
};

export const OjoGuardPromo: React.FC = () => {
  return (
    <AbsoluteFill style={{ backgroundColor: colors.bgObsidian }}>
      <Sequence durationInFrames={SCENE_1}>
        <Scene1Lifestyle />
      </Sequence>
      <Sequence from={SCENE_1} durationInFrames={SCENE_2}>
        <Scene2Device />
      </Sequence>
      <Sequence from={SCENE_1 + SCENE_2} durationInFrames={SCENE_3}>
        <Scene3Closing />
      </Sequence>
    </AbsoluteFill>
  );
};
