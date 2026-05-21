"""
╔══════════════════════════════════════════════════════════════╗
║     暖小圈 Python 安全微服务                                  ║
║                                                              ║
║  端口：8000（Java 主后端在 8080）                             ║
║                                                              ║
║  职责（Python 保留这部分是因为生态优势）：                    ║
║    1. 链接安全检测（三层过滤）                                ║
║    2. WAF（Web 应用防火墙）— 拦截 SQL 注入/XSS/命令注入      ║
║                                                              ║
║  Java 主后端每次用户发布内容时调用 /security/check           ║
║                                                              ║
║  每日推荐暖句不在后端处理，由前端直接调用一言公开 API。       ║
╚══════════════════════════════════════════════════════════════╝
"""
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from app.security.link_checker import link_checker
from app.security.waf import waf
import uvicorn

app = FastAPI(
    title="暖小圈安全微服务",
    description="链接检测 + WAF",
    version="2.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.post("/security/check")
async def check_content(request: Request):
    """
    Java 主后端调用此接口检测用户输入内容

    请求体: {"content": "用户输入的文字"}
    返回: {"safe": true/false, "reason": "拦截原因（安全时为空）"}
    """
    body = await request.json()
    content = body.get("content", "")

    # WAF 优先（拦截攻击代码）
    waf_safe, waf_reason = waf.check(content)
    if not waf_safe:
        return {"safe": False, "reason": f"[WAF] {waf_reason}"}

    # 链接检测（拦截违规网址）
    link_safe, link_reason = link_checker.check_content(content)
    if not link_safe:
        return {"safe": False, "reason": f"[链接] {link_reason}"}

    return {"safe": True, "reason": ""}


@app.get("/health")
async def health():
    return {"status": "ok", "service": "暖小圈安全微服务"}


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
