library(tidyverse)
library(RSelenium)
library(wdman)
library(rvest)
library(xml2)
library(stringr)

# ================================================================
# 🚀 0. 시작 시간 기록
# ================================================================
start_time <- Sys.time()
cat("🆕 크롤링 시작\n")
cat("⏰ 시작 시간:", format(start_time, "%Y-%m-%d %H:%M:%S"), "\n")

# ================================================================
# 🚀 1. ChromeDriver 실행 (봇 감지 우회 강화)
# ================================================================
c_drvr <- wdman::chrome(
  port = 4445L, 
  version = "latest",
  chromever = NULL
)

remDr <- remoteDriver(
  remoteServerAddr = "localhost",
  port = 4445L, 
  browserName = "chrome",
  extraCapabilities = list(
    chromeOptions = list(
      args = list(
        "--disable-blink-features=AutomationControlled",
        "--disable-dev-shm-usage",
        "--no-sandbox",
        "--disable-gpu",
        "--disable-extensions",
        "--disable-infobars",
        "--start-maximized",
        "--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
      ),
      excludeSwitches = list("enable-automation", "enable-logging"),
      useAutomationExtension = FALSE,
      prefs = list(
        "profile.default_content_setting_values.notifications" = 2,
        "credentials_enable_service" = FALSE,
        "profile.password_manager_enabled" = FALSE
      )
    )
  )
)

remDr$open()
remDr$maxWindow()
Sys.sleep(2)

# webdriver 속성 숨기기
remDr$executeScript("
  Object.defineProperty(navigator, 'webdriver', {get: () => undefined});
  Object.defineProperty(navigator, 'plugins', {get: () => [1, 2, 3, 4, 5]});
  Object.defineProperty(navigator, 'languages', {get: () => ['ko-KR', 'ko', 'en-US', 'en']});
")

cat("🌐 Chrome 브라우저가 실행되었습니다.\n")

scroll_bottom <- function(driver, wait = 2){
  driver$executeScript("window.scrollTo(0, document.body.scrollHeight);")
  Sys.sleep(wait)
}

# ================================================================
# 🚀 2. 시작 URL
# ================================================================
START_URL <- "https://www.yes24.com/product/category/display/001001014007"
BASE_DIR  <- "yes24_books/농축산학계열"

cat("🔗 페이지 로딩 중:", START_URL, "\n")
remDr$navigate(START_URL)

Sys.sleep(8)

current_url <- remDr$getCurrentUrl()[[1]]
page_title <- remDr$getTitle()[[1]]
cat("✅ 현재 URL:", current_url, "\n")
cat("📄 페이지 제목:", page_title, "\n")

if(grepl("차단|block|captcha|access denied", page_title, ignore.case = TRUE)){
  stop("🚫 YES24에서 접근을 차단했습니다!\n해결방법:\n1. VPN 사용\n2. 시간 간격 늘리기\n3. 다른 네트워크에서 시도")
}

Sys.sleep(3)

# ================================================================
# 🚀 3. 마지막 페이지 자동 감지 (재시도 로직)
# ================================================================
last_page <- -Inf
retry_count <- 0
max_retries <- 5

while(is.infinite(last_page) && retry_count < max_retries){
  retry_count <- retry_count + 1
  cat("🔍 마지막 페이지 감지 시도", retry_count, "/", max_retries, "\n")
  
  Sys.sleep(3)
  scroll_bottom(remDr, 2)
  Sys.sleep(2)
  
  dom <- read_html(remDr$getPageSource()[[1]])
  
  page_nums <- dom %>%
    html_nodes(".yesUI_pagen a.num, .yesUI_pagen a.end") %>%
    html_attr("title") %>%
    as.numeric()
  
  if(length(page_nums) > 0){
    last_page <- max(page_nums, na.rm = TRUE)
  }
}

if(is.infinite(last_page)){
  stop("❌ 마지막 페이지를 감지할 수 없습니다. 페이지 로딩을 확인해주세요.")
}

cat("📌 감지된 마지막 페이지 =", last_page, "\n")

# ================================================================
# 🚀 4. 페이지 루프
# ================================================================
for(p in 1:last_page){
  cat("\n====================================\n")
  cat("📄 현재 페이지:", p, "/", last_page, "\n")
  cat("====================================\n")
  
  if(p != 1){
    scroll_bottom(remDr, 2)
    
    # 현재 페이지 블록 확인
    dom_check <- read_html(remDr$getPageSource()[[1]])
    visible_pages <- dom_check %>%
      html_nodes(".yesUI_pagen a.num") %>%
      html_attr("title") %>%
      as.numeric()
    
    cat("👀 현재 보이는 페이지:", paste(visible_pages, collapse=", "), "\n")
    cat("🎯 이동할 페이지:", p, "\n")
    
    # 목표 페이지가 보이는 범위에 있는지 확인
    if(p %in% visible_pages){
      # 같은 블록 내 → 페이지 번호 직접 클릭
      xpath <- sprintf("//a[@class='num' and @title='%d']", p)
      elem <- try(remDr$findElement(using = "xpath", xpath), silent = TRUE)
      if(!inherits(elem, "try-error")){
        elem$clickElement()
        cat("✅ 페이지 번호 클릭:", p, "\n")
        Sys.sleep(3)
      }
    } else {
      # 다른 블록 → "다음" 버튼 클릭 (10→11, 20→21, 30→31...)
      cat("➡️ 블록 넘김: 다음 버튼 클릭\n")
      
      next_btn <- try(remDr$findElement(using = "xpath", "//a[contains(@class,'next')]"), silent = TRUE)
      
      if(!inherits(next_btn, "try-error")){
        next_btn$clickElement()
        cat("✅ 다음 버튼 클릭 완료 →", p, "페이지 블록으로 이동\n")
        Sys.sleep(4)
        
        # 다음 버튼 클릭 후 목표 페이지가 첫 번째 페이지가 아니면 클릭
        if(p %% 10 != 1){  # 11, 21, 31이 아닌 경우
          scroll_bottom(remDr, 1)
          xpath <- sprintf("//a[@class='num' and @title='%d']", p)
          elem <- try(remDr$findElement(using = "xpath", xpath), silent = TRUE)
          if(!inherits(elem, "try-error")){
            elem$clickElement()
            cat("✅ 페이지 번호 클릭:", p, "\n")
            Sys.sleep(3)
          }
        }
      } else {
        cat("⚠️ 다음 버튼을 찾을 수 없음\n")
      }
    }
    
    Sys.sleep(3)
  }
  
  scroll_bottom(remDr, 3)
  
  # 페이지 로딩 확인 (재시도)
  retry <- 0
  books_loaded <- FALSE
  
  while(!books_loaded && retry < 3){
    Sys.sleep(2)
    dom <- read_html(remDr$getPageSource()[[1]])
    books <- dom %>% html_nodes("a.gd_name")
    total_books <- length(books)
    
    if(total_books > 0){
      books_loaded <- TRUE
      cat("📚 로딩된 책 수:", total_books, "권\n")
    } else {
      retry <- retry + 1
      cat("⚠️ 책 목록 로딩 실패 - 재시도", retry, "/3\n")
      scroll_bottom(remDr, 2)
    }
  }
  
  if(!books_loaded){
    cat("❌ 페이지 로딩 실패 - 다음 페이지로\n")
    next
  }
  
  # ============================================================
  # 🚀 4-1. 책 루프
  # ============================================================
  for(i in 1:total_books){
    cat("\n----", p, "페이지", i, "번째 책 처리 중 ----\n")
    
    xpath <- sprintf("(//a[contains(@class,'gd_name')])[%d]", i)
    
    # 페이지 다시 로드 후 요소 찾기 (stale element 방지)
    scroll_bottom(remDr, 1)
    elem <- try(remDr$findElement(using = "xpath", xpath), silent = TRUE)
    
    if(inherits(elem, "try-error")){
      cat("⚠️ 책 요소 찾기 실패 → 스킵\n")
      next
    }
    
    elem$clickElement()
    Sys.sleep(3)
    scroll_bottom(remDr, 2)
    
    detail_html <- remDr$getPageSource()[[1]]
    dom_d <- read_html(detail_html)
    
    cat_lines <- dom_d %>% html_nodes("#infoset_goodsCate .yesAlertLi li") %>% html_text(trim = TRUE)
    idx <- grep("농축산학", cat_lines)
    
    if(length(idx) == 0){
      cat("❌ 농축산학 아님 → 스킵\n")
      remDr$goBack(); Sys.sleep(3)
      scroll_bottom(remDr, 1)
      next
    }
    
    parts <- strsplit(cat_lines[idx], ">")[[1]] %>% trimws() %>% gsub("[[:punct:]]", "", .)
    
    # 마지막이 "농축산학계열"이면 하위 폴더 없이 바로 저장
    if(parts[length(parts)] == "농축산학계열"){
      major <- ""  # 하위 폴더 없음
      cat("📂 분류: 농축산학계열 (하위 폴더 없음)\n")
    } else {
      major <- parts[length(parts)]
      cat("📂 분류:", major, "\n")
    }
    
    book_detail_url <- remDr$getCurrentUrl()[[1]]
    book_id <- str_extract(book_detail_url, "\\d+$")
    
    # book_id가 없으면 전체 숫자 사용 (fallback)
    if(is.na(book_id) || book_id == ""){
      book_id <- gsub("[^0-9]", "", url)
    }
    
    cat("📖 Book ID:", book_id, "\n")
    
    # major가 빈 문자열이면 BASE_DIR에 바로 저장
    if(major == ""){
      save_dir <- BASE_DIR
    } else {
      save_dir <- file.path(BASE_DIR, major)
    }
    
    dir.create(save_dir, recursive = TRUE, showWarnings = FALSE)
    save_path <- file.path(save_dir, paste0(book_id, ".html"))
    
    if(file.exists(save_path)){
      cat("⏭ 이미 저장됨 → 스킵:", save_path, "\n")
      remDr$goBack(); Sys.sleep(3)
      scroll_bottom(remDr, 1)
      next
    }
    
    write(detail_html, save_path)
    cat("💾 저장 완료:", save_path, "\n")
    
    # 사람처럼 행동 (랜덤 대기: 3~5초)
    wait_time <- runif(1, 3, 5)
    cat("⏱️ ", round(wait_time, 1), "초 대기 중...\n")
    Sys.sleep(wait_time)
    
    remDr$goBack()
    Sys.sleep(3)
    
    # goBack 후 페이지 재확인
    current_url_after <- try(remDr$getCurrentUrl()[[1]], silent = TRUE)
    if(!inherits(current_url_after, "try-error") && !grepl("category/display", current_url_after)){
      cat("⚠️ goBack 실패 - 목록 페이지 재로드\n")
      remDr$navigate(START_URL)
      Sys.sleep(5)
      
      # 현재 페이지로 다시 이동
      if(p > 1){
        for(nav_p in 2:p){
          if(nav_p %% 10 == 1 && nav_p > 10){
            next_btn <- try(remDr$findElement(using = "xpath", "//a[contains(@class,'next')]"), silent = TRUE)
            if(!inherits(next_btn, "try-error")) next_btn$clickElement()
            Sys.sleep(3)
          } else if(nav_p > 1){
            scroll_bottom(remDr, 1)
            page_btn <- try(remDr$findElement(using = "xpath", sprintf("//a[@class='num' and @title='%d']", nav_p)), silent = TRUE)
            if(!inherits(page_btn, "try-error")) page_btn$clickElement()
            Sys.sleep(2)
          }
        }
      }
    }
    
    scroll_bottom(remDr, 1)
  }
}

cat("\n🎉 농축산학 계열 전체 HTML 저장 완료!\n")

# ================================================================
# ⏱️ 총 소요 시간 계산
# ================================================================
end_time <- Sys.time()
elapsed_time <- difftime(end_time, start_time, units = "auto")

cat("\n====================================\n")
cat("📊 크롤링 완료 통계\n")
cat("====================================\n")
cat("⏰ 시작 시간:", format(start_time, "%Y-%m-%d %H:%M:%S"), "\n")
cat("🏁 종료 시간:", format(end_time, "%Y-%m-%d %H:%M:%S"), "\n")
cat("⌛ 총 소요 시간:", round(elapsed_time, 2), attr(elapsed_time, "units"), "\n")

elapsed_secs <- as.numeric(difftime(end_time, start_time, units = "secs"))
hours <- floor(elapsed_secs / 3600)
minutes <- floor((elapsed_secs %% 3600) / 60)
seconds <- round(elapsed_secs %% 60)
cat("📈 상세 시간:", sprintf("%d시간 %d분 %d초", hours, minutes, seconds), "\n")
cat("====================================\n")

remDr$close()
c_drvr$stop()