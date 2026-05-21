"""
数据库模型定义
"""
from sqlalchemy import Column, Integer, String, DateTime, Text, Enum, Decimal, Boolean, JSON, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime
from app.utils.database import Base

class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    phone = Column(String(11), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    nickname = Column(String(50), default="新用户")
    avatar = Column(String(500), default="")
    education_level = Column(Enum('小学', '初中', '高中', '专升本', '本科', '考研', '考公', '自考'), default='高中')
    level = Column(Integer, default=1)
    points = Column(Integer, default=0)
    theme = Column(String(20), default='default')
    created_at = Column(DateTime, default=datetime.now)
    updated_at = Column(DateTime, default=datetime.now, onupdate=datetime.now)
    
    # 关联关系
    study_plans = relationship("StudyPlan", back_populates="user")
    resources = relationship("Resource", back_populates="uploader")
    behaviors = relationship("UserBehavior", back_populates="user")

class StudyPlan(Base):
    __tablename__ = "study_plans"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey('users.id'), nullable=False)
    title = Column(String(100), nullable=False)
    goal = Column(Text)
    duration = Column(Integer, nullable=False)  # 天数
    daily_hours = Column(Decimal(3, 1))
    ai_generated = Column(JSON)  # AI生成的完整计划
    progress = Column(Decimal(5, 2), default=0)
    status = Column(Enum('进行中', '已完成', '已放弃'), default='进行中')
    created_at = Column(DateTime, default=datetime.now)
    
    user = relationship("User", back_populates="study_plans")

class Resource(Base):
    __tablename__ = "resources"

    id = Column(Integer, primary_key=True, index=True)
    type = Column(Enum('官方预置', '用户上传'), nullable=False)
    uploader_id = Column(Integer, ForeignKey('users.id'), nullable=True)
    title = Column(String(200), nullable=False)
    description = Column(Text)
    file_url = Column(String(500))
    file_type = Column(Enum('PDF', 'Word', '视频', '图片', '链接'))
    education_level = Column(String(20))
    subject = Column(String(50))
    tags = Column(JSON)
    views = Column(Integer, default=0)
    likes = Column(Integer, default=0)
    collects = Column(Integer, default=0)
    recommend_score = Column(Decimal(5, 2), default=0)
    created_at = Column(DateTime, default=datetime.now)
    
    uploader = relationship("User", back_populates="resources")
    behaviors = relationship("UserBehavior", back_populates="resource")

class UserBehavior(Base):
    __tablename__ = "user_behaviors"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey('users.id'), nullable=False)
    resource_id = Column(Integer, ForeignKey('resources.id'), nullable=False)
    action = Column(Enum('浏览', '点赞', '收藏', '下载'), nullable=False)
    duration = Column(Integer, default=0)  # 停留时长(秒)
    created_at = Column(DateTime, default=datetime.now)
    
    user = relationship("User", back_populates="behaviors")
    resource = relationship("Resource", back_populates="behaviors")

class Accounting(Base):
    __tablename__ = "accounting"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey('users.id'), nullable=False)
    type = Column(Enum('收入', '支出'), nullable=False)
    amount = Column(Decimal(10, 2), nullable=False)
    category = Column(String(50))
    note = Column(Text)
    record_date = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=datetime.now)

class MenstrualRecord(Base):
    __tablename__ = "menstrual_records"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey('users.id'), nullable=False)
    start_date = Column(DateTime, nullable=False)
    end_date = Column(DateTime)
    cycle_days = Column(Integer)
    symptoms = Column(JSON)
    created_at = Column(DateTime, default=datetime.now)

class Badge(Base):
    __tablename__ = "badges"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(50), nullable=False)
    description = Column(Text)
    icon = Column(String(255))
    unlock_condition = Column(JSON)
    points_reward = Column(Integer, default=0)

class UserBadge(Base):
    __tablename__ = "user_badges"
    
    user_id = Column(Integer, ForeignKey('users.id'), primary_key=True)
    badge_id = Column(Integer, ForeignKey('badges.id'), primary_key=True)
    unlock_time = Column(DateTime, default=datetime.now)
