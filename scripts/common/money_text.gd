extends RefCounted
## Numbers and amounts of money as the Dutch write them: thousands with a point, cents after
## a comma, the euro sign with a space before the amount ("€ 1.284,50"). Shared by the HUD,
## the menus, the shop and machine screens, the price signs, the conversations and the story.
##   const MoneyText = preload("res://scripts/common/money_text.gd")


## A whole number with its thousands grouped by points: 1234567 -> "1.234.567".
static func thousands(number: int) -> String:
	var digits := str(absi(number))
	var grouped := ""
	while digits.length() > 3:
		grouped = "." + digits.substr(digits.length() - 3) + grouped
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if number < 0 else "") + digits + grouped


## Euros without the sign (where an icon stands for it): 1284.5 -> "1.284,50".
static func amount(euros_amount: float) -> String:
	var cents := roundi(euros_amount * 100.0)
	return ("-" if cents < 0 else "") + thousands(absi(cents) / 100) + ",%02d" % (absi(cents) % 100)


## Euros with the sign: 0.5 -> "€ 0,50".
static func euros(euros_amount: float) -> String:
	return "€ " + amount(euros_amount)
