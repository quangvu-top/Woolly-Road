class_name I18n
extends RefCounted
## English is the source text. Vietnamese is a Translation built here: Labels translate their text by themselves
## (auto translate), formatted text goes through tr("Level %d") % n. Language picked in Settings > Language,
## kept in user://settings.cfg.

const LANGS := ["en", "vi"]

const VI := {
	"PLAY": "CHƠI", "Level %d": "Màn %d", "Full": "Đầy", "Daily Gift": "Quà ngày", "Starter Pack": "Gói khởi đầu",
	"Remove Ads": "Tắt QC", "SHOP": "CỬA HÀNG", "HOME": "VỀ NHÀ", "ROAD %d/%d": "ĐƯỜNG %d/%d", "FREE %d/%d": "TRỐNG %d/%d",
	"Tap a sheep to send it onto the road!": "Chạm vào cừu để đưa nó ra đường!",
	"Sheep walk into the pen with the same colour on top.": "Cừu vào chuồng có con trên cùng cùng màu.",
	"A full pen pushes its bottom sheep back onto the road!": "Chuồng đầy sẽ đẩy con dưới cùng ra đường!",
	"4 of a colour clears the pen. Clear them all to win!": "4 con cùng màu là dọn sạch chuồng. Dọn hết để thắng!",
	"If the road fills with sheep that can't find a pen, you lose!": "Đường đầy cừu mà không con nào vào được chuồng là thua!",
	"Stuck? Try Undo, +1 Road or a Hint!": "Bí? Thử Hoàn tác, +1 Đường hoặc Gợi ý!",
	"Pause": "Tạm dừng", "RESTART": "CHƠI LẠI", "Watch Ads": "Xem QC", "Restore Purchase": "Khôi phục giao dịch",
	"Privacy Policy": "Chính sách riêng tư", "Settings": "Cài đặt", "Language": "Ngôn ngữ", "Contact": "Liên hệ",
	"Privacy settings": "Cài đặt riêng tư", "Levels": "Các màn", "Keep playing?": "Chơi tiếp?", "1 ROAD": "1 ĐƯỜNG",
	"The road is full!\nGet one more space and keep going": "Đường đã đầy!\nThêm một chỗ để chơi tiếp",
	"FREE": "MIỄN PHÍ", "STARTER PACK": "GÓI KHỞI ĐẦU", "Undo": "Hoàn tác", "+1 Road": "+1 Đường", "Hint": "Gợi ý",
	"Take back your last sheep.": "Lấy lại con cừu vừa gửi.", "One more space on the road.": "Thêm một chỗ trên đường.",
	"Shows the best sheep to send.": "Chỉ ra con cừu nên gửi.", "CONGRATULATIONS!": "CHÚC MỪNG!", "Reward": "Phần thưởng",
	"Continue": "Tiếp tục", "Home": "Về nhà", "LEVEL FAILED!": "THUA RỒI!", "Heart": "Tim", "RETRY": "CHƠI LẠI",
	"The road is full and no sheep can find a pen.": "Đường đầy và không con cừu nào vào được chuồng.",
	"No sheep left to send, but the pens are still mixed up.": "Hết cừu để gửi mà chuồng vẫn lẫn màu.",
	"The flock keeps going round in circles!": "Đàn cừu cứ đi vòng tròn mãi!",
	"DAILY GIFT": "QUÀ HẰNG NGÀY", "Day %d": "Ngày %d", "CLAIM": "NHẬN", "Tomorrow": "Ngày mai",
	"Profile": "Hồ sơ", "Avatar": "Ảnh", "Frame": "Khung", "SAVE": "LƯU", "Best: Level %d": "Cao nhất: Màn %d",
	"Change name": "Đổi tên",
	"Enter a nickname (3-14 characters), containing only English letters, numbers, underscores, periods, hyphens, and no other special characters.": "Nhập biệt danh 3-14 ký tự, chỉ gồm chữ không dấu, số, gạch dưới, dấu chấm, gạch ngang, không có ký tự đặc biệt khác.",
	"Refill": "Nạp",
	"3-14 letters, numbers, _ . - only": "3-14 ký tự: chữ không dấu, số, _ . -",
	"Changed name successfully!": "Đổi tên thành công!",
	"Do you want to read\nthe Privacy Policy?": "Bạn có muốn đọc\nChính sách riêng tư?", "NO": "KHÔNG", "YES": "CÓ",
	"Privacy policy link is not set yet": "Chưa có link chính sách riêng tư",
	"Refill Lives": "Nạp tim", "Next lives in": "Tim tiếp theo sau", "Full of Heart": "Đầy tim", "Full Heart": "Tim đã đầy",
	"Remove Ads include:\n• Break ads\n• Banner ads": "Tắt QC gồm:\n• QC giữa màn\n• QC banner",
	"See offer": "Xem gói", "No, thanks!": "Không, cảm ơn!", "NO ADS": "KHÔNG QC", "BUNDLE": "GÓI", "FREE COINS": "XU MIỄN PHÍ",
	"BOOSTERS": "TRỢ GIÚP", "NEW BOOSTER\nUNLOCKED!": "MỞ KHÓA\nTRỢ GIÚP MỚI!", "Are you sure?": "Bạn chắc chứ?",
	"QUIT": "THOÁT", "You will lose\n1 Heart!": "Bạn sẽ mất\n1 tim!", "Ads break": "Nghỉ xem QC", "Rate us": "Đánh giá",
	"Enjoy the game?\nPlease tell us your thoughts.": "Bạn thích game chứ?\nHãy cho chúng tôi biết nhé.",
	"SURE": "ĐỒNG Ý", "Loading...": "Đang tải...", "OWNED": "ĐÃ MUA", "HARD LEVEL": "MÀN KHÓ",
	"The road is full!": "Đường đã đầy!", "+1 road space!": "+1 chỗ trên đường!",
	"No ad right now, try again soon": "Chưa có QC, thử lại sau nhé", "Nothing to undo": "Không có gì để hoàn tác",
	"The road is as long as it gets!": "Đường đã dài tối đa!", "Wait for the flock to settle...": "Đợi đàn cừu đứng yên đã...",
	"No winning move - try Undo!": "Không còn nước thắng - thử Hoàn tác!", "+1 booster!": "+1 trợ giúp!",
	"Not enough coins": "Không đủ xu", "Unlocks at Level %d": "Mở khóa ở Màn %d",
	"Purchases restored": "Đã khôi phục giao dịch", "Nothing to restore": "Không có gì để khôi phục",
	"Starter Pack added!": "Đã nhận Gói khởi đầu!", "Ads removed. Thank you!": "Đã tắt QC. Cảm ơn bạn!",
	"Ads are already removed": "QC đã được tắt rồi", "Payment pending...": "Đang chờ thanh toán...",
	"This purchase could not be verified": "Không xác minh được giao dịch",
	"Purchase failed, try again later": "Mua thất bại, thử lại sau", "+%d coins!": "+%d xu!", "+1 heart!": "+1 tim!",
	"Hearts refilled!": "Đã nạp đầy tim!", "Thanks for your feedback!": "Cảm ơn góp ý của bạn!",
	"You finished every level! More coming soon.": "Bạn đã qua hết các màn! Sắp có màn mới.",
	"Frame unlocked!": "Đã mở khung!", "Profile saved": "Đã lưu hồ sơ", "No hearts left": "Hết tim rồi",
	"Combo x%d!": "Combo x%d!",
	"Password": "Mật khẩu", "Cheat": "Cheat", "WIN LEVEL": "THẮNG MÀN", "Add coins": "Thêm xu", "ADD": "THÊM",
	"Wrong password": "Sai mật khẩu", "Type an amount": "Nhập số xu", "Level won (cheat)": "Đã thắng màn (cheat)",
	"Send a sheep and start sorting colours": "Gửi một chú cừu để bắt đầu xếp màu",
	"Sheep go into the pen with their colour": "Cừu sẽ vào chuồng cùng màu",
	"Pushed-out sheep join the road": "Cừu bị đẩy ra sẽ quay lại đường",
}

static var _done := false


static func setup() -> void:
	if _done:
		return
	_done = true
	var t := Translation.new()
	t.locale = "vi"
	for k in VI:
		t.add_message(k, VI[k])
	TranslationServer.add_translation(t)


static func saved_lang() -> String:
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	var l: String = cfg.get_value("ui", "lang", "")
	if l == "":   # first run: follow the phone when it is Vietnamese
		l = "vi" if OS.get_locale_language() == "vi" else "en"
	return l if l in LANGS else "en"


static func apply(lang: String) -> void:
	setup()
	TranslationServer.set_locale(lang)
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("ui", "lang", lang)
	cfg.save("user://settings.cfg")
