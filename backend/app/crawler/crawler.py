"""
暖小圈爬虫系统
- 每日随机时间爬取一次（6:00-10:59 随机，每次跑完重新抽签）
- 语录：多个免费API轮换，一个挂了自动切换下一个，都挂了用内置库
- 资源：多个来源轮换 + 内置预设兜底
"""
import requests
import random
import schedule
import time
import logging
from datetime import datetime
from bs4 import BeautifulSoup

try:
    from app.models.models import DailyQuote, Resource
    from app.utils.database import SessionLocal
    _DB_AVAILABLE = True
except ImportError:
    _DB_AVAILABLE = False

logging.basicConfig(level=logging.INFO, format='[%(asctime)s] %(message)s')
log = logging.getLogger("crawler")

# ──────────────────────────────────────────────────────────────
# 语录数据源（按优先级排列，挂了自动换下一个）
# ──────────────────────────────────────────────────────────────
QUOTE_SOURCES = [
    {
        "name": "一言·励志",
        "url": "https://v1.hitokoto.cn/?encode=json&lang=cn&c=k",  # c=k:感叹
        "parser": "hitokoto",
    },
    {
        "name": "一言·动漫",
        "url": "https://v1.hitokoto.cn/?encode=json&lang=cn&c=b",  # c=b:动漫
        "parser": "hitokoto",
    },
    {
        "name": "一言·游戏",
        "url": "https://v1.hitokoto.cn/?encode=json&lang=cn&c=d",
        "parser": "hitokoto",
    },
    {
        "name": "一言·文学",
        "url": "https://v1.hitokoto.cn/?encode=json&lang=cn&c=h",
        "parser": "hitokoto",
    },
    {
        "name": "内置语录库",           # 最终兜底，永远成功
        "url": None,
        "parser": "preset",
    },
]

# ──────────────────────────────────────────────────────────────
# 内置语录库（兜底用，50 条）
# ──────────────────────────────────────────────────────────────
_PRESET_QUOTES = [
    ("成功不是将来才有的，而是从决定去做的那一刻起，持续累积而成。", "佚名", "励志"),
    ("学习这件事不在乎有没有人教你，最重要的是在于你自己有没有觉悟和恒心。", "法布尔", "学习"),
    ("今天不走，明天要跑。", "哈佛校训", "励志"),
    ("只有比别人更早、更勤奋地努力，才能尝到成功的滋味。", "佚名", "励志"),
    ("学习的敌人是自己的满足，要认真学习一点东西，必须从不自满开始。", "毛泽东", "学习"),
    ("天才就是无止境刻苦勤奋的能力。", "卡莱尔", "励志"),
    ("你的努力，别人不一定放在眼里，你不努力，别人一定放在心里。", "佚名", "励志"),
    ("没有谁的幸运，凭空而来，只有当你足够努力，你才会足够幸运。", "佚名", "励志"),
    ("宝剑锋从磨砺出，梅花香自苦寒来。", "佚名", "励志"),
    ("不要等待机会，而要创造机会。", "林肯", "励志"),
    ("读书不觉已春深，一寸光阴一寸金。", "王贞白", "学习"),
    ("少壮不努力，老大徒伤悲。", "汉乐府", "励志"),
    ("书山有路勤为径，学海无涯苦作舟。", "韩愈", "学习"),
    ("业精于勤，荒于嬉；行成于思，毁于随。", "韩愈", "学习"),
    ("黑发不知勤学早，白首方悔读书迟。", "颜真卿", "学习"),
    ("不积跬步，无以至千里；不积小流，无以成江海。", "荀子", "励志"),
    ("生命不是要超越别人，而是要超越自己。", "佚名", "励志"),
    ("每一个你羡慕的收获，都有一段你看不见的付出。", "佚名", "励志"),
    ("你所浪费的今天，是昨天死去的人奢望的明天。", "佚名", "励志"),
    ("纸上得来终觉浅，绝知此事要躬行。", "陆游", "学习"),
    ("问渠那得清如许？为有源头活水来。", "朱熹", "学习"),
    ("欲穷千里目，更上一层楼。", "王之涣", "励志"),
    ("千磨万击还坚劲，任尔东西南北风。", "郑板桥", "励志"),
    ("咬定青山不放松，立根原在破岩中。", "郑板桥", "励志"),
    ("长风破浪会有时，直挂云帆济沧海。", "李白", "励志"),
    ("路漫漫其修远兮，吾将上下而求索。", "屈原", "励志"),
    ("不经历风雨，怎么见彩虹。", "佚名", "励志"),
    ("静以修身，俭以养德。", "诸葛亮", "修身"),
    ("三人行，必有我师焉。", "孔子", "学习"),
    ("知之者不如好之者，好之者不如乐之者。", "孔子", "学习"),
    ("学而不思则罔，思而不学则殆。", "孔子", "学习"),
    ("吾日三省吾身。", "曾子", "修身"),
    ("博学而笃志，切问而近思。", "孔子", "学习"),
    ("人生最大的快乐，是自己的努力变成了现实。", "佚名", "励志"),
    ("坚持是一种信仰，专注是一种态度。", "佚名", "励志"),
    ("你现在的努力，终将照亮你最好的未来。", "佚名", "励志"),
    ("今日事今日毕，不把麻烦留明天。", "佚名", "励志"),
    ("进步不一定要跑，但要一直走。", "佚名", "励志"),
    ("无论多慢，只要走在路上就好。", "佚名", "励志"),
    ("你的潜力，从来不是用来证明给别人看的。", "佚名", "励志"),
    ("压力是学习的动力，而不是障碍。", "佚名", "学习"),
    ("真正的坚持，不是忍，是喜欢。", "佚名", "励志"),
    ("每一次努力，都是在为将来的你存钱。", "佚名", "励志"),
    ("做不到的事，坚持一下就能做到了。", "佚名", "励志"),
    ("结果不重要，过程中的成长才是你的。", "佚名", "励志"),
    ("好记性不如烂笔头。", "中国谚语", "学习"),
    ("温故而知新，可以为师矣。", "孔子", "学习"),
    ("学无止境。", "荀子", "学习"),
    ("时间就是金钱，效率就是生命。", "佚名", "励志"),
    ("自律给你自由。", "佚名", "励志"),
]


class QuoteCrawler:
    """每日语录爬虫（多源轮换 + 内置兜底）"""

    def __init__(self):
        self.headers = {
            "User-Agent": (
                "Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 "
                "Chrome/110.0 Mobile Safari/537.36"
            )
        }

    # ── 解析器 ─────────────────────────────────────────────────

    def _parse_hitokoto(self, url: str) -> list[dict]:
        """解析一言API（返回单条）"""
        resp = requests.get(url, headers=self.headers, timeout=8)
        data = resp.json()
        content = data.get("hitokoto", "")
        author = data.get("from_who") or data.get("from") or "佚名"
        if not content or len(content) < 5:
            return []
        return [{
            "content": content.strip(),
            "author": str(author).strip() or "佚名",
            "category": "励志",
            "source": "一言API",
            "crawl_time": datetime.now(),
        }]

    def _parse_preset(self, url) -> list[dict]:
        """内置语录库（取 5 条随机）"""
        sampled = random.sample(_PRESET_QUOTES, min(5, len(_PRESET_QUOTES)))
        return [{
            "content": c, "author": a, "category": cat,
            "source": "内置语录库", "crawl_time": datetime.now(),
        } for c, a, cat in sampled]

    # ── 主入口 ────────────────────────────────────────────────

    def crawl_quotes(self) -> list[dict]:
        """
        按优先级轮换数据源，第一个成功就返回。
        每个源最多 2 次重试。失败则切换下一个。
        """
        for source in QUOTE_SOURCES:
            name = source["name"]
            for attempt in range(2):
                try:
                    if source["parser"] == "preset":
                        quotes = self._parse_preset(None)
                    elif source["parser"] == "hitokoto":
                        quotes = self._parse_hitokoto(source["url"])
                    else:
                        quotes = []

                    if quotes:
                        log.info(f"[语录] 数据源「{name}」成功，获取 {len(quotes)} 条")
                        self._save_quotes(quotes)
                        return quotes
                except Exception as e:
                    log.warning(f"[语录] 数据源「{name}」第{attempt+1}次失败: {e}")
                    time.sleep(1)

            log.warning(f"[语录] 数据源「{name}」已跳过，切换下一个")

        return []

    def _save_quotes(self, quotes: list[dict]):
        if not _DB_AVAILABLE:
            log.info("[语录] 数据库不可用，跳过保存（调试模式）")
            return
        db = SessionLocal()
        try:
            added = 0
            for q in quotes:
                exists = db.query(DailyQuote).filter(
                    DailyQuote.content == q["content"]
                ).first()
                if not exists:
                    db.add(DailyQuote(**q))
                    added += 1
            db.commit()
            log.info(f"[语录] 新增 {added} 条入库")
        except Exception as e:
            db.rollback()
            log.error(f"[语录] 入库失败: {e}")
        finally:
            db.close()

    def get_today_quote(self, db=None):
        """获取今日语录（供 API 调用）"""
        if db is None or not _DB_AVAILABLE:
            q = random.choice(_PRESET_QUOTES)
            return {"content": q[0], "author": q[1], "category": q[2]}
        today = datetime.now().date()
        quote = db.query(DailyQuote).filter(DailyQuote.show_date == today).first()
        if not quote:
            quote = db.query(DailyQuote).filter(DailyQuote.is_shown == False).first()
            if not quote:
                db.query(DailyQuote).update({DailyQuote.is_shown: False})
                db.commit()
                quote = db.query(DailyQuote).first()
            if quote:
                quote.is_shown = True
                quote.show_date = today
                db.commit()
        return quote


# ──────────────────────────────────────────────────────────────
# 资源爬虫（多源 + 内置兜底，每周一次）
# ──────────────────────────────────────────────────────────────

RESOURCE_SOURCES = [
    # 可填写合法的开放资源 API 或公开教育网站
    # {"name": "xxx", "url": "https://xxx.com/api/resources", "parser": "generic_json"},
    {"name": "内置资源库", "url": None, "parser": "preset"},
]

_PRESET_RESOURCES = [
    {
        "type": "官方预置",
        "title": "高考数学必考知识点总结",
        "description": "涵盖高考数学所有重点知识点，含公式和例题",
        "file_url": "",
        "file_type": "PDF",
        "education_level": "高中",
        "subject": "数学",
        "tags": ["高考", "数学", "知识点"],
    },
    {
        "type": "官方预置",
        "title": "考研英语词汇 5500",
        "description": "考研英语大纲词汇，带音标和例句",
        "file_url": "",
        "file_type": "PDF",
        "education_level": "考研",
        "subject": "英语",
        "tags": ["考研", "英语", "词汇"],
    },
    {
        "type": "官方预置",
        "title": "大学物理公式汇总",
        "description": "力学、热学、电磁学、光学、近代物理全覆盖",
        "file_url": "",
        "file_type": "PDF",
        "education_level": "大学",
        "subject": "物理",
        "tags": ["大学物理", "公式", "汇总"],
    },
    {
        "type": "官方预置",
        "title": "Python 入门到精通笔记",
        "description": "基础语法、函数、面向对象、常用库，附带练习题",
        "file_url": "",
        "file_type": "PDF",
        "education_level": "通用",
        "subject": "编程",
        "tags": ["Python", "编程", "入门"],
    },
]


class ResourceCrawler:
    """学习资源爬虫"""

    def crawl_resources(self):
        for source in RESOURCE_SOURCES:
            try:
                if source["parser"] == "preset":
                    self._save_resources(_PRESET_RESOURCES)
                    return
            except Exception as e:
                log.warning(f"[资源] 数据源「{source['name']}」失败: {e}")

    def _save_resources(self, resources: list[dict]):
        if not _DB_AVAILABLE:
            log.info("[资源] 数据库不可用，跳过保存")
            return
        db = SessionLocal()
        try:
            for r in resources:
                r["created_at"] = datetime.now()
                exists = db.query(Resource).filter(Resource.title == r["title"]).first()
                if not exists:
                    db.add(Resource(**r))
            db.commit()
        except Exception as e:
            db.rollback()
            log.error(f"[资源] 入库失败: {e}")
        finally:
            db.close()


# ──────────────────────────────────────────────────────────────
# 随机每日调度（每次跑完后重新抽下次时间）
# ──────────────────────────────────────────────────────────────

quote_crawler = QuoteCrawler()
resource_crawler = ResourceCrawler()


def _pick_random_time() -> str:
    """随机返回 6:00-10:59 之间的时间字符串"""
    h = random.randint(6, 10)
    m = random.randint(0, 59)
    return f"{h:02d}:{m:02d}"


def _run_quote_and_reschedule():
    """跑完语录爬虫后立刻为明天抽一个新的随机时间"""
    log.info("[调度] 开始今日语录爬取...")
    quote_crawler.crawl_quotes()

    schedule.clear("quote_job")
    next_time = _pick_random_time()
    schedule.every().day.at(next_time).do(_run_quote_and_reschedule).tag("quote_job")
    log.info(f"[调度] 明天语录爬取时间已定为 {next_time}")


def _run_resource_and_reschedule():
    """跑完资源爬虫后重新调度（每 7 天一次，时间也随机）"""
    log.info("[调度] 开始资源爬取...")
    resource_crawler.crawl_resources()

    schedule.clear("resource_job")
    next_time = _pick_random_time()
    schedule.every(7).days.at(next_time).do(_run_resource_and_reschedule).tag("resource_job")
    log.info(f"[调度] 下次资源爬取已定为 7 天后 {next_time}")


def start_crawler_scheduler():
    """启动定时爬虫调度（在 main.py 的 lifespan 里调用）"""
    # 初始时各抽一个随机时间
    quote_time = _pick_random_time()
    resource_time = _pick_random_time()

    schedule.every().day.at(quote_time).do(_run_quote_and_reschedule).tag("quote_job")
    schedule.every(7).days.at(resource_time).do(_run_resource_and_reschedule).tag("resource_job")

    log.info(f"[调度] 爬虫调度已启动：语录首次={quote_time}，资源首次=7天后 {resource_time}")

    # 启动时先跑一次资源（填充初始数据库）
    resource_crawler.crawl_resources()

    while True:
        schedule.run_pending()
        time.sleep(30)  # 每 30 秒检查一次


# 直接运行时用于测试
if __name__ == "__main__":
    log.info("=== 独立测试爬虫 ===")
    results = quote_crawler.crawl_quotes()
    for r in results:
        print(f"  [{r['author']}] {r['content']}")
