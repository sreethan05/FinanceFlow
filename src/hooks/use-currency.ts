"use client";
import { useEffect, useState } from "react";
export function useCurrency(){const[currency,setCurrency]=useState("INR");useEffect(()=>{let active=true;void fetch("/api/settings").then(r=>r.json()).then(b=>{if(active&&b.data?.currency)setCurrency(b.data.currency)}).catch(()=>undefined);return()=>{active=false}},[]);return currency}
