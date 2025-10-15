from fastapi import FastAPI, Request, Response, HTTPException
import hmac
import hashlib
import os
from dotenv import load_dotenv
import logic

load_dotenv()



app = FastAPI()

# new tss


@app.get('/health')
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy 3"}

# 
