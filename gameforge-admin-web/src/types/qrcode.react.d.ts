declare module "qrcode.react" {
  import * as React from "react";

  export type QRCodeCanvasProps = {
    value: string;
    size?: number;
    bgColor?: string;
    fgColor?: string;
    level?: "L" | "M" | "Q" | "H";
    includeMargin?: boolean;
    imageSettings?: {
      src: string;
      height: number;
      width: number;
      excavate?: boolean;
    };
  };

  export const QRCodeCanvas: React.FC<QRCodeCanvasProps>;
}
