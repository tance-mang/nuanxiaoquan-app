"""
配置文件
"""
from pydantic_settings import BaseSettings
from typing import Optional

class Settings(BaseSettings):
    # 应用配置
    APP_NAME: str = "暖小圈"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = True
    
    # 数据库配置
    MYSQL_HOST: str = "localhost"
    MYSQL_PORT: int = 3306
    MYSQL_USER: str = "root"
    MYSQL_PASSWORD: str = "123456"
    MYSQL_DATABASE: str = "warmcircle"
    
    # Redis配置
    REDIS_HOST: str = "localhost"
    REDIS_PORT: int = 6379
    REDIS_DB: int = 0
    
    # JWT配置
    SECRET_KEY: str = "your-secret-key-change-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7天
    
    # 豆包AI配置（火山引擎方舟 v3，兼容 OpenAI 格式）
    # API Key 形如 ark-xxxxxxxx，对应"火山引擎-方舟平台-API Key 管理"
    # 模型 ID 取自 https://www.volcengine.com/docs/82379/1330310
    ARK_API_KEY: str = "ark-c3409235-6b79-4db3-935b-3eb989211a26-a0ada"
    ARK_BASE_URL: str = "https://ark.cn-beijing.volces.com/api/v3"
    ARK_MODEL: str = "doubao-1-5-pro-256k-250115"

    # 旧字段保留兜底（避免依赖它的代码报 AttributeError），新代码请用 ARK_*
    DOUBAO_ACCESS_KEY: str = ""
    DOUBAO_SECRET_KEY: str = ""
    DOUBAO_ENDPOINT: str = ""
    DOUBAO_MODEL: str = ""
    
    # 阿里云OSS配置
    OSS_ACCESS_KEY_ID: str = "your_oss_ak"
    OSS_ACCESS_KEY_SECRET: str = "your_oss_sk"
    OSS_ENDPOINT: str = "oss-cn-hangzhou.aliyuncs.com"
    OSS_BUCKET_NAME: str = "warmcircle"
    
    # 腾讯云短信配置
    TENCENT_SECRET_ID: str = "your_tencent_id"
    TENCENT_SECRET_KEY: str = "your_tencent_key"
    SMS_APP_ID: str = "your_sms_appid"
    SMS_SIGN_NAME: str = "暖小圈"
    
    # 文件上传配置
    MAX_FILE_SIZE: int = 50 * 1024 * 1024  # 50MB
    ALLOWED_EXTENSIONS: list = ['.pdf', '.doc', '.docx', '.ppt', '.pptx', '.jpg', '.png', '.mp4']
    
    class Config:
        env_file = ".env"

settings = Settings()

# 数据库连接字符串
DATABASE_URL = f"mysql+pymysql://{settings.MYSQL_USER}:{settings.MYSQL_PASSWORD}@{settings.MYSQL_HOST}:{settings.MYSQL_PORT}/{settings.MYSQL_DATABASE}?charset=utf8mb4"
