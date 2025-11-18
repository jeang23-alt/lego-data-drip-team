library(tidyverse)
library(RSelenium)
library(wdman)
library(rvest)
library(xml2)
library(dplyr)
library(stringr)

# ------------------------------------------------------
# 1️⃣ ChromeDriver 실행
# ------------------------------------------------------
c_drvr <- wdman::chrome(port = 4445L, version = "latest")
remDr <- remoteDriver(remoteServerAddr = "localhost",
                      port = 4445L, browserName = "chrome")
remDr$open()

# ------------------------------------------------------
# 2️⃣ LEGO 테마 페이지 접속
# ------------------------------------------------------
url <- "https://www.lego.com/ko-kr/themes"
remDr$navigate(url)
Sys.sleep(6)

# ------------------------------------------------------
# 3️⃣ 팝업 자동 클릭
# ------------------------------------------------------
try({
  remDr$findElement("css selector",
                    "button[data-test='age-gate-grown-up-cta']")$clickElement()
  Sys.sleep(2)
}, silent = TRUE)

try({
  remDr$findElement("css selector",
                    "button[data-test='cookie-accept-all']")$clickElement()
  Sys.sleep(2)
}, silent = TRUE)

# ------------------------------------------------------
# 4️⃣ 화면 스크롤 (Lazy load)
# ------------------------------------------------------
remDr$executeScript("window.scrollTo(0, document.body.scrollHeight);")
Sys.sleep(4)

# ------------------------------------------------------
# 5️⃣ HTML 가져오기
# ------------------------------------------------------
page <- read_html(remDr$getPageSource()[[1]])

# ------------------------------------------------------
# 6️⃣ URL 수집 (/theme + /themes)
# ------------------------------------------------------
theme_links <- page %>%
  html_nodes("a[href^='/ko-kr/theme']") %>% 
  html_attr("href") %>%
  unique()

# ------------------------------------------------------
# 7️⃣ 테마명 수집 (h2 / h3)
# ------------------------------------------------------
theme_names <- page %>%
  html_nodes("h2, h3") %>%
  html_text(trim = TRUE) %>%
  unique()

# URL과 이름 개수 맞추기
min_len <- min(length(theme_links), length(theme_names))
themes_df <- tibble(
  theme_id   = seq_len(min_len),
  theme_name = theme_names[1:min_len],
  theme_url  = paste0("https://www.lego.com", theme_links[1:min_len])
)

# ------------------------------------------------------
# 🔥 마지막 5개 행 삭제 (footer/기타 정보 제거)
# ------------------------------------------------------
themes_df <- themes_df[1:(nrow(themes_df) - 5), ]

# ------------------------------------------------------
# 8️⃣ 저장
# ------------------------------------------------------
write.csv(themes_df, "lego_themes.csv", row.names = FALSE)

cat("\n🎉 최종 테마:", nrow(themes_df), "개 저장 완료!\n")
print(themes_df)




# ------------------------------------------------------
# 9️⃣ 종료
# ------------------------------------------------------
try({
  remDr$close()
  c_drvr$stop()
}, silent = TRUE)

library(dplyr) # 혹시 로드 안 되어 있다면
themes_df <- themes_df %>%
  mutate(theme_url = lead(theme_url))

# 2. 확인: 이제 짝이 맞는지 봅니다
head(themes_df)
tail(themes_df)
# 43번째 행의 URL을 직접 지정 (예시 URL입니다, 실제 확인한 URL로 바꿔주세요!)
themes_df$theme_url[43] <- "https://www.lego.com/ko-kr/themes/wicked"

# 확인
tail(themes_df, 1)


# 코드가 잘 안 먹히면 이 방법을 쓰세요 (가장 확실)
christmas_row <- tibble(
  theme_id = 44,
  theme_name = "크리스마스",
  theme_url = "https://www.lego.com/ko-kr/categories/christmas" # 실제 URL 확인 필요
)

themes_df <- bind_rows(themes_df, christmas_row)
View(themes_df)

write_csv(themes_df, "lego_themes_clean.csv")
