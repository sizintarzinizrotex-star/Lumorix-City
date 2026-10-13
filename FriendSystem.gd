class_name LumorixFriendSystem
extends Node

signal friend_message(text: String, severity: String)
signal friend_state_changed
signal friend_request_received(request: Dictionary)
signal friend_request_resolved(player_id: String, accepted: bool)
signal friend_visit_started(player_id: String)
signal friend_visit_ended(player_id: String)
signal gift_sent(player_id: String, item_id: String, quantity: int)
signal social_notification_created(notification: Dictionary)
signal social_achievement_unlocked(achievement_id: String)

const MAX_FRIENDS := 100
const MAX_CHAT_MESSAGES := 100
const MAX_NOTIFICATIONS := 100
const MAX_SOCIAL_HISTORY := 200
const MAX_GIFT_QUANTITY := 1000
const MAX_DAILY_GIFTS := 20

var state: Node
var friends: Array[Dictionary] = []
var pending_requests: Array[Dictionary] = []
var sent_requests: Array[Dictionary] = []
var visits: Array[Dictionary] = []
var chat_messages: Array[Dictionary] = []
var notifications: Array[Dictionary] = []
var social_history: Array[Dictionary] = []
var social_achievements: Array[String] = []

var active_visit: Dictionary = {}
var daily_gift_count: int = 0
var last_gift_day: int = -1

var multiplayer_enabled: bool = false
var social_network_ready: bool = true


func initialize(game_state: Node) -> void:
	state = game_state
	multiplayer_enabled = false
	social_network_ready = true


func add_friend(player_id: String, city_id: String, display_name: String) -> bool:
	if player_id.is_empty() or _has_friend(player_id):
		return false

	if friends.size() >= MAX_FRIENDS:
		friend_message.emit("Arkadaş listesi dolu.", "warning")
		return false

	var friend := {
		"player_id": player_id,
		"city_id": city_id,
		"display_name": display_name if not display_name.is_empty() else player_id,
		"online": false,
		"last_seen": Time.get_unix_time_from_system(),
		"friend_since": Time.get_unix_time_from_system(),
		"relationship_score": 0
	}

	friends.append(friend)
	_record_social("friend_added", player_id, {"display_name": friend.display_name})

	_create_notification(
		"friend_added",
		"Yeni arkadaş",
		"%s arkadaş listene eklendi." % friend.display_name
	)

	friend_message.emit("Arkadaş eklendi: %s" % friend.display_name, "success")
	friend_state_changed.emit()
	return true


func send_friend_request(player_id: String, city_id: String, display_name: String) -> bool:
	if player_id.is_empty() or _has_friend(player_id):
		return false

	for request in sent_requests:
		if request.get("player_id", "") == player_id:
			return false

	var request := {
		"player_id": player_id,
		"city_id": city_id,
		"display_name": display_name if not display_name.is_empty() else player_id,
		"created_at": Time.get_unix_time_from_system()
	}

	sent_requests.append(request)
	_record_social("friend_request_sent", player_id, request)

	friend_message.emit(
		"👥 %s oyuncusuna arkadaşlık isteği gönderildi." % request.display_name,
		"success"
	)

	friend_state_changed.emit()
	return true


func receive_friend_request(player_id: String, city_id: String, display_name: String) -> bool:
	if player_id.is_empty() or _has_friend(player_id):
		return false

	for request in pending_requests:
		if request.get("player_id", "") == player_id:
			return false

	var request := {
		"player_id": player_id,
		"city_id": city_id,
		"display_name": display_name if not display_name.is_empty() else player_id,
		"created_at": Time.get_unix_time_from_system()
	}

	pending_requests.append(request)

	_create_notification(
		"friend_request",
		"Arkadaşlık isteği",
		"%s sana arkadaşlık isteği gönderdi." % request.display_name
	)

	friend_request_received.emit(request.duplicate(true))
	friend_state_changed.emit()
	return true


func accept_friend_request(player_id: String) -> bool:
	for request in pending_requests:
		if request.get("player_id", "") == player_id:
			pending_requests.erase(request)

			var added := add_friend(
				request.get("player_id", ""),
				request.get("city_id", ""),
				request.get("display_name", "")
			)

			friend_request_resolved.emit(player_id, added)
			return added

	return false


func reject_friend_request(player_id: String) -> bool:
	for request in pending_requests:
		if request.get("player_id", "") == player_id:
			pending_requests.erase(request)
			friend_request_resolved.emit(player_id, false)
			_record_social("friend_request_rejected", player_id, {})
			friend_state_changed.emit()
			return true

	return false


func remove_friend(player_id: String) -> bool:
	for friend in friends:
		if friend.get("player_id", "") == player_id:
			friends.erase(friend)
			_record_social("friend_removed", player_id, {})
			friend_state_changed.emit()
			return true

	return false


func set_friend_online(player_id: String, online: bool) -> bool:
	for friend in friends:
		if friend.get("player_id", "") == player_id:
			friend["online"] = online
			friend["last_seen"] = Time.get_unix_time_from_system()
			friend_state_changed.emit()
			return true

	return false


func visit_friend(player_id: String) -> bool:
	for friend in friends:
		if friend.get("player_id", "") == player_id:
			active_visit = {
				"player_id": player_id,
				"city_id": friend.get("city_id", ""),
				"display_name": friend.get("display_name", player_id),
				"read_only": true,
				"started_at": Time.get_unix_time_from_system()
			}

			visits.append(active_visit.duplicate(true))
			_record_social("city_visit_started", player_id, {})

			friend_message.emit(
				"👥 %s şehrine güvenli ziyaret başladı. Değişiklik yetkisi yok."
				% friend.get("display_name", player_id),
				"info"
			)

			friend_visit_started.emit(player_id)
			friend_state_changed.emit()
			return true

	return false


func leave_friend_visit() -> void:
	if active_visit.is_empty():
		return

	var player_id: String = str(active_visit.get("player_id", ""))
	active_visit.clear()

	_record_social("city_visit_ended", player_id, {})
	friend_visit_ended.emit(player_id)
	friend_message.emit("🏠 Arkadaş şehrinden çıkıldı.", "info")
	friend_state_changed.emit()


func is_visiting_friend() -> bool:
	return not active_visit.is_empty()


func can_modify_city() -> bool:
	return active_visit.is_empty()


func send_help(player_id: String, help_type: String) -> bool:
	if not _has_friend(player_id) or help_type.strip_edges().is_empty():
		return false

	_increase_relationship(player_id, 2)
	_record_social("help_sent", player_id, {"help_type": help_type})

	friend_message.emit("🤝 Yardım gönderildi: %s" % help_type, "success")
	friend_state_changed.emit()
	return true


func send_resource_gift(player_id: String, item_id: String, quantity: int) -> bool:
	if not _has_friend(player_id):
		return false

	if item_id.strip_edges().is_empty() or quantity <= 0:
		return false

	if quantity > MAX_GIFT_QUANTITY:
		friend_message.emit("Hediye miktarı sınırı aşıldı.", "warning")
		return false

	_reset_daily_gift_counter_if_needed()

	if daily_gift_count >= MAX_DAILY_GIFTS:
		friend_message.emit("Günlük hediye sınırına ulaşıldı.", "warning")
		return false

	daily_gift_count += 1

	_increase_relationship(player_id, 3)
	_record_social("resource_gift", player_id, {
		"item_id": item_id,
		"quantity": quantity
	})

	gift_sent.emit(player_id, item_id, quantity)
	friend_message.emit(
		"🎁 %s ×%d arkadaşına gönderildi." % [item_id, quantity],
		"success"
	)

	friend_state_changed.emit()
	return true


func send_chat(player_id: String, message: String) -> bool:
	if not _has_friend(player_id):
		return false

	var clean := message.strip_edges().left(240)

	if clean.is_empty():
		return false

	chat_messages.append({
		"from": state.player_id if state != null else "local_player",
		"to": player_id,
		"message": clean,
		"timestamp": Time.get_unix_time_from_system()
	})

	if chat_messages.size() > MAX_CHAT_MESSAGES:
		chat_messages.pop_front()

	_increase_relationship(player_id, 1)
	_record_social("chat_message", player_id, {"message": clean})

	friend_message.emit("💬 Mesaj gönderildi.", "success")
	friend_state_changed.emit()
	return true


func get_chat(player_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for message in chat_messages:
		if message.get("from", "") == player_id or message.get("to", "") == player_id:
			result.append(message.duplicate(true))

	return result


func get_friends() -> Array[Dictionary]:
	return friends.duplicate(true)


func get_pending_requests() -> Array[Dictionary]:
	return pending_requests.duplicate(true)


func get_sent_requests() -> Array[Dictionary]:
	return sent_requests.duplicate(true)


func get_active_visit() -> Dictionary:
	return active_visit.duplicate(true)


func get_notifications() -> Array[Dictionary]:
	return notifications.duplicate(true)


func mark_notification_read(notification_id: int) -> bool:
	for notification in notifications:
		if int(notification.get("id", -1)) == notification_id:
			notification["read"] = true
			friend_state_changed.emit()
			return true

	return false


func get_social_history() -> Array[Dictionary]:
	return social_history.duplicate(true)


func get_social_achievements() -> Array[String]:
	return social_achievements.duplicate()


func compare_friend_city(
	player_id: String,
	population: int,
	development_lwl: float,
	lucb: int,
	happiness: float
) -> Dictionary:
	if not _has_friend(player_id):
		return {}

	var friend := _get_friend(player_id)

	return {
		"player_id": player_id,
		"display_name": friend.get("display_name", player_id),
		"population": population,
		"development_lwl": development_lwl,
		"lucb": lucb,
		"happiness": happiness,
		"friend_online": friend.get("online", false),
		"relationship_score": friend.get("relationship_score", 0)
	}


func get_friend_count() -> int:
	return friends.size()


func get_online_friend_count() -> int:
	var count := 0

	for friend in friends:
		if friend.get("online", false):
			count += 1

	return count


func get_unread_notification_count() -> int:
	var count := 0

	for notification in notifications:
		if not notification.get("read", false):
			count += 1

	return count


func get_social_status() -> Dictionary:
	return {
		"friends": friends.size(),
		"online_friends": get_online_friend_count(),
		"pending_requests": pending_requests.size(),
		"notifications": notifications.size(),
		"unread_notifications": get_unread_notification_count(),
		"chat_messages": chat_messages.size(),
		"visits": visits.size(),
		"social_achievements": social_achievements.size(),
		"multiplayer_enabled": false,
		"social_network_ready": social_network_ready,
		"active_visit": not active_visit.is_empty()
	}


func unlock_social_achievement(achievement_id: String) -> bool:
	if achievement_id.is_empty() or social_achievements.has(achievement_id):
		return false

	social_achievements.append(achievement_id)

	_create_notification(
		"social_achievement",
		"🏆 Sosyal başarı",
		"Yeni sosyal başarı açıldı: %s" % achievement_id
	)

	social_achievement_unlocked.emit(achievement_id)
	friend_state_changed.emit()
	return true


func restore_data(data: Dictionary) -> void:
	friends.assign(data.get("friends", []))
	pending_requests.assign(data.get("pending_requests", []))
	sent_requests.assign(data.get("sent_requests", []))
	visits.assign(data.get("visits", []))
	chat_messages.assign(data.get("chat_messages", []))
	notifications.assign(data.get("notifications", []))
	social_history.assign(data.get("social_history", []))
	social_achievements.assign(data.get("social_achievements", []))
	active_visit = data.get("active_visit", {})
	daily_gift_count = int(data.get("daily_gift_count", 0))
	last_gift_day = int(data.get("last_gift_day", -1))

	friend_state_changed.emit()


func export_data() -> Dictionary:
	return {
		"friends": friends,
		"pending_requests": pending_requests,
		"sent_requests": sent_requests,
		"visits": visits,
		"chat_messages": chat_messages,
		"notifications": notifications,
		"social_history": social_history,
		"social_achievements": social_achievements,
		"active_visit": active_visit,
		"daily_gift_count": daily_gift_count,
		"last_gift_day": last_gift_day,
		"multiplayer_enabled": false,
		"social_network_ready": social_network_ready
	}


func _has_friend(player_id: String) -> bool:
	for friend in friends:
		if friend.get("player_id", "") == player_id:
			return true

	return false


func _get_friend(player_id: String) -> Dictionary:
	for friend in friends:
		if friend.get("player_id", "") == player_id:
			return friend

	return {}


func _increase_relationship(player_id: String, amount: int) -> void:
	for friend in friends:
		if friend.get("player_id", "") == player_id:
			friend["relationship_score"] = int(
				friend.get("relationship_score", 0)
			) + amount
			return


func _get_friend_name(player_id: String) -> String:
	var friend := _get_friend(player_id)
	return friend.get("display_name", player_id)


func _create_notification(
	notification_type: String,
	title: String,
	message: String
) -> void:
	var notification := {
		"id": Time.get_unix_time_from_system(),
		"type": notification_type,
		"title": title,
		"message": message,
		"timestamp": Time.get_unix_time_from_system(),
		"read": false
	}

	notifications.append(notification)

	if notifications.size() > MAX_NOTIFICATIONS:
		notifications.pop_front()

	social_notification_created.emit(notification.duplicate(true))


func _record_social(
	action: String,
	player_id: String,
	data: Dictionary
) -> void:
	social_history.append({
		"action": action,
		"player_id": player_id,
		"data": data.duplicate(true),
		"timestamp": Time.get_unix_time_from_system()
	})

	if social_history.size() > MAX_SOCIAL_HISTORY:
		social_history.pop_front()

	_check_social_achievements()


func _check_social_achievements() -> void:
	if friends.size() >= 1:
		unlock_social_achievement("first_friend")

	if friends.size() >= 10:
		unlock_social_achievement("social_circle")

	if visits.size() >= 1:
		unlock_social_achievement("first_city_visit")

	if visits.size() >= 10:
		unlock_social_achievement("city_explorer")

	if social_history.size() >= 25:
		unlock_social_achievement("social_activity")


func _reset_daily_gift_counter_if_needed() -> void:
	var current_day: int = int(Time.get_datetime_dict_from_system().get("day", 0))

	if last_gift_day != current_day:
		last_gift_day = current_day
		daily_gift_count = 0
