declare module "qrcode" {
  export type QRCodeToDataURLOptions = {
    width?: number;
    margin?: number;
    color?: {
      dark?: string;
      light?: string;
    };
    errorCorrectionLevel?: "L" | "M" | "Q" | "H";
  };

  const QRCode: {
    toDataURL(text: string, opts?: QRCodeToDataURLOptions): Promise<string>;
  };

  export default QRCode;
}
