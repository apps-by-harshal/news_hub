/// The NewsAPI top-headlines categories, in chip display order.
///
/// `general` comes first because it is the default category. The data layer
/// maps each value to its API string with an exhaustive `switch` (Step 19),
/// so this enum holds no API strings.
enum NewsCategory {
  general,
  business,
  entertainment,
  health,
  science,
  sports,
  technology,
}
