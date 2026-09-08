import { loadFont as loadPoppins } from "@remotion/google-fonts/Poppins";
import { loadFont as loadMono } from "@remotion/google-fonts/IBMPlexMono";

const poppins = loadPoppins("normal", { weights: ["300", "400", "600"] });
const mono = loadMono("normal", { weights: ["400", "500"] });

export const fontFamily = poppins.fontFamily;
export const monoFontFamily = mono.fontFamily;
