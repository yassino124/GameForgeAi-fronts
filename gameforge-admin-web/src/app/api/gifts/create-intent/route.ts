import { NextResponse } from "next/server";
import Stripe from "stripe";

const stripeSecret = process.env.STRIPE_SECRET_KEY;
const stripe = new Stripe(stripeSecret || "");

export async function POST(req: Request) {
  try {
    if (!stripeSecret) {
      return NextResponse.json(
        { success: false, message: "Missing STRIPE_SECRET_KEY env var" },
        { status: 500 },
      );
    }

    const { giftId, amount } = await req.json();

    if (!giftId || !amount) {
      return NextResponse.json({ success: false, message: "Missing gift details" }, { status: 400 });
    }

    const amountNum = Number(amount);
    if (!Number.isFinite(amountNum) || amountNum <= 0) {
      return NextResponse.json({ success: false, message: "Invalid amount" }, { status: 400 });
    }

    // Create a PaymentIntent with the specific amount
    // In a real app, you'd calculate the amount on the server based on the giftId
    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(amountNum * 100), // Stripe expects cents
      currency: "usd",
      metadata: {
        giftId,
        type: "live_gift",
      },
      automatic_payment_methods: {
        enabled: true,
      },
    });

    if (!paymentIntent.client_secret) {
      return NextResponse.json(
        { success: false, message: "Stripe did not return a client_secret" },
        { status: 502 },
      );
    }

    return NextResponse.json({
      success: true,
      clientSecret: paymentIntent.client_secret,
    });
  } catch (error: any) {
    console.error("Stripe Intent Error:", error);
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}
