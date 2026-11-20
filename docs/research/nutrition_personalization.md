# Legon Lift: nutrition, personalization and lifestyle layer

Research basis for the onboarding, targets, food guidance, progress tracking, motivation, safety and achievements in **Legon Lift**. Legon Lift is an offline Android (Flutter) app for a beginner training at the University of Ghana (Legon) campus gym.

- Machine-readable companion: `docs/research/personalization.json` (all formulas as parameters, meal list, milestones, PAR-Q+ items, tips keyed by context).
- Default user: male, ~95 kg, ~172 cm, age unknown (default 22), complete beginner, goal = lose fat and build muscle, 3 days/week, Push/Pull/Legs, 45-60 min sessions, hot and humid climate.
- **Disclaimer to show in the app:** this is general fitness and nutrition education, not medical advice. If you have a medical condition, ask a doctor first. The University of Ghana Hospital (Legon) is on campus.

Numbers marked `~` are approximate. Protein values per food come from typical portions, using the FAO/INFOODS West African Food Composition Table (2019) and USDA FoodData Central. Rounding is deliberate because street-food portions vary a lot. The app should always show them as approximate.

---

## 1. Onboarding and target formulas

### 1.1 Inputs to collect (in this order, max ~2 minutes)

| # | Field | Type / options | Default | Why it matters |
|---|---|---|---|---|
| 1 | Safety screen (PAR-Q+ style, section 5) | 7 yes/no + 3 Ghana-specific | all "no" required to continue without a warning | Screens for people who should see a doctor first |
| 2 | Units | kg/cm or lb/ft-in | kg/cm | Ghana uses metric. Some users think of height in feet |
| 3 | Sex | male / female | male | Mifflin-St Jeor constant (+5 / -161) |
| 4 | Age (years) | 16-80 int | 22 | BMR (-5 kcal per year). Users under 18 see a "train with supervision" note |
| 5 | Height | 140-210 cm | 172 | BMR, BMI, reference weight, waist-to-height |
| 6 | Current weight | 40-250 kg | 95 | Everything |
| 7 | Goal weight (optional) | kg | blank | Used for protein reference weight if given, and for milestones |
| 8 | Waist (optional, can skip) | cm at the navel | blank | Best simple fat-loss marker (section 3) |
| 9 | Daily activity outside the gym | sedentary / lightly active / active / very active, each with plain-language examples | lightly active | Sets the TDEE multiplier |
| 10 | Average daily steps (optional, "don't know" allowed) | int | don't know (treated as 5,000) | Sets the step target |
| 11 | Goal | lose fat and build muscle (recomp) / lose fat / build muscle / maintain and get fit | lose fat and build muscle | Calorie adjustment |
| 12 | Training experience | never / under 3 months / 3-12 months / over 1 year | never | Volume, progression speed, tips |
| 13 | Days per week | 2-6 | 3 | Split selection, activity factor |
| 14 | Session length | 30 / 45 / 60 / 75 min | 60 (45-60 including warm-up) | Exercise count, water target |
| 15 | Preferred split | Push/Pull/Legs; Upper/Lower; Chest+Back / Legs / Arms+Shoulders; Full body; Custom | PPL | Programme generator |
| 16 | Injuries / limitations | multi-select: knee, lower back, shoulder, wrist/elbow, hip, ankle, none, other (text) | none | Swaps exercises and adds cues |
| 17 | Usual training time | morning / afternoon / evening | evening | Heat and hydration tips (avoid 12:00-15:00 walks in the dry season) |
| 18 | Food budget | tight / moderate / comfortable | tight | Ranks meal suggestions by cost tier |
| 19 | Diet notes | no pork, vegetarian, lactose intolerant, groundnut allergy, fish allergy | none | Filters the meal list |
| 20 | Reminders | weigh-in time, workout days | 06:30 weigh-in; Mon/Wed/Fri | Adherence |

Everything is stored on the device only. Weight, waist and photos are sensitive, so keep them out of any sync or analytics by default.

### 1.2 Formulas

**BMI** = weight_kg / (height_m)^2. Show it as context only. Never use it as the main goal.

**BMR: Mifflin-St Jeor (1990).** It was the most accurate common equation in non-obese and obese adults in the ADA evidence review (Frankenfield et al., 2005). Expect about ±10% individual error. This is why the app adapts later (section 3).

```
male:   BMR = 10 × weight_kg + 6.25 × height_cm − 5 × age_y + 5
female: BMR = 10 × weight_kg + 6.25 × height_cm − 5 × age_y − 161
```

**TDEE = BMR × activity multiplier.** The multiplier describes the whole lifestyle and already includes the training. Do not add exercise calories on top.

| Level | Multiplier | Plain-language description shown in the app |
|---|---|---|
| sedentary | 1.20 | Mostly sitting (lectures, laptop), little walking, no training |
| lightly_active | **1.375** | Walk around campus daily, train 1-3×/week (**default for this user**) |
| moderately_active | 1.55 | On your feet a lot, or train 4-5×/week, or 10k+ steps daily |
| very_active | 1.725 | Physical job or hard training 6-7×/week |
| extra_active | 1.90 | Athlete with twice-daily training or heavy manual labour |

Overweight people tend to overestimate their activity. If the user is unsure between two levels, pick the lower one.

**Calorie target by goal** (rounded to the nearest 50 kcal):

| Goal | Adjustment | Rule |
|---|---|---|
| Lose fat and build muscle (recomp) with BMI ≥ 25 | −20% | Overweight beginners can lose fat and gain muscle at the same time in a moderate deficit if protein is high and they lift (Longland 2016; Barakat 2020) |
| Recomp with BMI < 25 | −10% | Leaner people recomp best near maintenance |
| Lose fat | −20% (allow −25% only if BMI ≥ 30) | ISSN body-composition stand: moderate deficits preserve lean mass better |
| Build muscle | +5 to +10% | Lean gain for beginners |
| Maintain | 0% | |

**Safety floors:** target ≥ max(BMR, 1,500 kcal) for men, and ≥ max(BMR × 0.95, 1,200 kcal) for women. Never go below 1,200 or 1,500 without medical supervision.

**Expected rate of loss:** aim for **0.5-0.75% of body weight per week** (Helms 2014; Aragon 2017). For 95 kg that is **~0.48-0.71 kg/week**. The app converts this to a range and compares it against the 7-day-average trend (section 3). Rule of thumb: about 7,700 kcal per kg of fat. In reality the deficit needed per kg rises over time (Hall 2008), which is why weekly feedback beats prediction.

**Protein: why "reference weight" for overweight users.** The ISSN protein position stand (Jäger 2017) recommends **1.4-2.0 g/kg/day** for people who exercise, and higher amounts (2.3-3.1 g/kg of lean mass; Helms 2014) during a deficit to keep muscle. Morton et al.'s 2018 meta-analysis found the muscle-gain benefit levels off around **1.6 g/kg (95% CI upper bound ~2.2)**. These g/kg figures come from mostly lean subjects. Multiplying them by the total weight of someone at BMI 32 overshoots, because fat tissue needs almost no protein. It gives 95 × 2.2 = 209 g, which is expensive and hard to eat in Ghana on a student budget. Examine.com and most dietitians therefore use goal weight, adjusted weight or height-based reference weight for people with obesity. Legon Lift uses:

```
reference_weight_kg =
    weight_kg                                  if BMI < 25
    max(goal_weight_kg, 25 × height_m²)        if BMI ≥ 25 and goal weight entered
    25 × height_m²                             if BMI ≥ 25 (weight at BMI 25)

protein_target_g  = round_to_5(1.9 × reference_weight_kg)   # middle of 1.6-2.2 g/kg
protein_min_g     = round_to_5(1.6 × reference_weight_kg)   # "good day"
protein_max_g     = round_to_5(2.2 × reference_weight_kg)   # no benefit above this
sanity check: protein_target_g ≥ 1.2 × actual weight_kg (≈ adjusted-bodyweight methods)
per-meal goal     = 0.4 g/kg reference weight (≈ 25-40 g), over 3-5 eating occasions (ISSN nutrient timing, Kerksick 2017)
```

**Fat and carbohydrate** (shown only in "advanced numbers" mode, since the default is the protein checklist, not counting): fat = max(0.8 g/kg reference weight, 25% of kcal), and carbs = whatever calories remain. Carbs fuel training, so they should not be cut to near zero.

**Water in a hot, humid climate.** EFSA's adequate intake is 2.5 L/day total water for men and the US IOM's is 3.7 L/day (about 20% of it comes from food). Both are for temperate climates. Accra averages 27-31 °C with 70-85% humidity, and sweat losses during exercise in heat are often 0.5-1.5 L/hour (ACSM fluid replacement stand, Sawka 2007; NATA, McDermott 2017).

```
base_ml          = clamp(30 ml × weight_kg, 2000, 4000)
hot_climate_ml   = +500
training_ml      = +750 × (session_minutes / 60)  on training days
water_target_ml  = round_to_250(base + hot + training), hard cap 5000
display          = litres AND "pure water" sachets (500 ml each)
```

- Check: pale-straw urine means you are drinking enough. Dark yellow means drink more.
- Don't drink more than ~1 L per hour. Over-drinking plain water can cause hyponatraemia.
- For sessions over 60 minutes, or heavy sweating, use ORS or add a pinch of salt with food, or drink a commercial electrolyte drink.

**Daily steps.** WHO (2020) recommends 150-300 min/week of moderate activity plus muscle-strengthening work on 2 or more days. Lifting covers the second part. Walking around campus covers much of the first. Paluch et al. (Lancet Public Health, 2022) found the mortality benefit levels off around 8,000-10,000 steps/day in adults under 60.

```
if baseline_steps unknown: start_target = 7000
else start_target = clamp(baseline_steps + 2000, 6000, 10000)
every 2 weeks: if target hit on ≥5 of 7 days, target += 1000 (max 10000)
```

### 1.3 Worked example: male, 95 kg, 172 cm, 22 years, lightly active, recomp

| Step | Calculation | Result |
|---|---|---|
| BMI | 95 / 1.72² | **32.1** (obesity class I; context only) |
| BMR | 10×95 + 6.25×172 − 5×22 + 5 = 950 + 1075 − 110 + 5 | **1,920 kcal** |
| TDEE | 1,920 × 1.375 | **2,640 kcal** |
| Target | 2,640 × 0.80 = 2,112, rounded to the nearest 50 | **2,100 kcal/day** (above the 1,920 BMR floor ✓) |
| Daily deficit | 2,640 − 2,100 | ~540 kcal, about 0.5 kg/week of fat (plus 1-2 kg of water and glycogen in weeks 1-2) |
| Target rate | 0.5-0.75% × 95 kg | **0.48-0.71 kg/week** |
| Reference weight | 25 × 1.72² | **74 kg** |
| Protein | 1.9 × 74 = 140.6 | **140 g/day** (range 120-165; 1.47 g/kg of actual weight ✓) |
| Per meal | 0.4 × 74 | ~30 g × 4 eating occasions (or 35 g × 4) |
| Protein points | 140 / 20 | **7 points/day** (section 2.4) |
| Fat (advanced) | max(0.8×74 = 59, 25% × 2100 / 9 = 58) | ~60 g |
| Carbs (advanced) | (2100 − 140×4 − 60×9) / 4 | ~250 g |
| Water | 30×95 = 2,850 + 500 = 3,350, rounded to 250 → rest day; + 750 on a 60-min training day | **3.25 L rest day (~6½ sachets), 4.0 L training day (8 sachets)** |
| Steps | baseline unknown | **7,000/day**, rising toward 10,000 |
| Waist (if entered) | WHO: > 94 cm raised risk, > 102 cm high risk (men); waist-to-height goal < 0.5 means < 86 cm | Track the trend |

If age is entered as 30 instead of 22, BMR is 40 kcal lower (1,880) and the target is about 2,050. Recalculate all targets **every 4 kg lost or every 8 weeks**, whichever comes first.

---

## 2. Ghana-specific eating guide

### 2.1 Principles (no calorie counting needed)

1. **Protein at every meal.** Aim for about 2 palms of protein (fish, egg, chicken, beans, wagashi) each time you eat.
2. **Shrink the swallow, not the soup's protein.** Kenkey, banku, fufu, waakye, rice and gari are where most extra calories hide. Start with ¾ of your usual ball or scoop. After 2 weeks, try ½ if hunger is fine.
3. **Watch the oil.** Palm oil, groundnut paste, shito and frying oil are ~120 kcal per tablespoon. Skim the red layer off soups. Ask for "small shito" and grilled instead of fried.
4. **Add vegetables you already eat.** Kontomire, garden eggs, okro, cabbage/salad, tomatoes, onions, pepper sauce, and fruit (pineapple, watermelon, oranges, banana, pawpaw). WHO recommends ≥ 400 g of fruit and vegetables a day, which is about 5 handfuls.
5. **Drink water, not calories.** A 500 ml soft drink, malt or sobolo with sugar is ~200-250 kcal. Swap for water, unsweetened sobolo, or diet drinks.
6. **Don't skip breakfast and then overeat a massive late waakye.** Spreading protein over 3-5 meals is better for muscle (ISSN nutrient timing).

### 2.2 Hand portion guide (Precision Nutrition hand method, sized for a ~95 kg man in a deficit)

| Food group | Per meal | Ghana examples | 1 portion ≈ |
|---|---|---|---|
| Protein | **2 palms** | fish, chicken, eggs, beans, wagashi, khebab, tuna/sardines | 1 palm ≈ 100 g cooked meat/fish ≈ 20-25 g protein |
| Starch / swallow | **1-2 cupped hands** | rice, waakye, yam, plantain, gari; swallows: ½-1 ball | 1 cupped hand ≈ ½ cup cooked rice ≈ 120 kcal |
| Vegetables | **2 fists** | kontomire, garden egg, okro, cabbage, tomato-onion pepper | |
| Fats | **1 thumb** (max 2) | palm oil, groundnut paste, avocado, shito | 1 thumb ≈ 1 tbsp ≈ 100-120 kcal |

### 2.3 Meal ideas with approximate protein

Cost tier is relative (₵ = cheapest, ₵₵₵ = priciest). Prices change too fast to hard-code.

| Meal | What to order or cook | Protein | kcal | Cost | Make it fit the goal |
|---|---|---|---|---|---|
| Oats + milk + eggs | 60 g oats cooked in 250 ml milk (or water + 3 tbsp milk powder), 2 boiled eggs, banana | ~30 g | ~550 | ₵₵ | Little or no sugar. Cinnamon or banana for sweetness |
| Hausa koko upgrade | 1 cup Hausa koko + 2 tbsp milk powder stirred in + 3 koose + 2 boiled eggs | ~25 g | ~550 | ₵ | Plain koko is only ~3 g protein. The milk and eggs make it a real meal. Koose is fried, so 3 pieces max |
| Egg bread | 3-egg omelette (onion, tomato, pepper, a little oil) in 2 slices of tea/brown bread | ~24 g | ~450 | ₵ | Ask the egg seller for less margarine or oil. Add a 4th egg for +6 g |
| Sardine bread | 1 tin sardines (drained) + 2 slices bread + onion/tomato | ~26 g | ~450 | ₵ | Drain the oil |
| Tuna or sardine with gari foto / yam | 1 tin tuna in brine + 1 cupped hand gari foto or boiled yam + veg | ~30 g | ~450 | ₵₵ | Tuna in brine is leaner than tuna in oil |
| Red red, upgraded | 1½ cups beans stew + 1 boiled egg or piece of fish + ½ plantain (boiled, or a few fried slices) | ~25-30 g | ~650 | ₵ | Beans are great cheap protein. Ask for less palm oil and fewer fried plantain slices |
| Waakye, smart order | 1 scoop waakye + 2 boiled eggs + 1 piece fish (or chicken) + salad + small shito | ~35 g | ~700 | ₵₵ | Skip or limit the gari, spaghetti ("talia") and extra shito. A full "everything" plate is often 1,100+ kcal. Wele (cow skin) adds little useful protein |
| Kenkey with fish | ½-1 ball Ga kenkey + 1 medium fried/grilled fish (or 4-5 small "keta school boys") + pepper with onion/tomato | ~30 g | ~600-750 | ₵ | Kenkey is mostly carbs (~8-10 g protein per ball). Get 2 fish rather than 2 balls. Grilled is better than fried |
| Banku and tilapia | 1 medium grilled tilapia + 1 small banku + pepper and onions | ~35 g | ~750 | ₵₵₵ | Tilapia is high-protein and lean. Share a big banku |
| Light soup with fish/goat | Light soup, 2 pieces fish or goat + ½-1 small fufu or rice ball | ~30 g | ~600 | ₵₵ | Low-oil soup, so a good choice. The meat pieces are what count |
| Groundnut soup, smart | 1 ladle groundnut soup + 1 chicken thigh/drumstick (or fish) + ½ omo tuo (rice ball) | ~30 g | ~750 | ₵₵ | Groundnut soup is calorie-dense. Skim the oil layer and keep the ball small |
| Kontomire stew + ampesi | Kontomire stew with 2 eggs or momone/mackerel, a little agushie + boiled yam/plantain | ~25-30 g | ~600 | ₵ | 1 tbsp palm oil per serving at home. Leafy greens are a nutrient bonus |
| Garden egg stew + yam | Garden egg stew with tinned mackerel or 2 eggs + boiled yam | ~25 g | ~550 | ₵ | |
| Jollof / fried rice + chicken | 1 cupped hand-plus of rice + 1 chicken quarter (grilled) + coleslaw (small) | ~35 g | ~750 | ₵₵ | Ask for grilled chicken, less rice and less coleslaw dressing |
| Okro stew + banku | Okro stew with fish/crab/meat + small banku | ~25 g | ~650 | ₵₵ | |
| Khebab snack | 3 sticks beef or chicken khebab | ~25-30 g | ~300 | ₵₵ | Good post-gym snack near campus. Skip the fried yam |
| Wagashi stew | 100 g wagashi (Fulani cheese) in tomato stew + rice or yam | ~25 g | ~550 | ₵₵ | |
| Soya chunks stew | 40 g dry soya chunks in stew + rice/yam | ~20 g | ~450 | ₵ | Very cheap vegetarian protein |
| Yoghurt + groundnuts | 200 ml plain yoghurt + 30 g roasted groundnuts | ~15 g | ~350 | ₵ | Choose plain or low-sugar yoghurt over sweet sachet yoghurt drinks |
| Boiled eggs | 3-4 eggs | ~18-24 g | ~220-300 | ₵ | Easiest emergency protein |
| Milk | 2 sachets/tbsp-servings of milk powder (~40 g) in water, or 500 ml fresh milk | ~10-16 g | ~200-300 | ₵ | |
| Whey shake (optional) | 1 scoop whey in water | ~25 g | ~120 | ₵₵₵ | Convenient but not needed. Food first |

**Low-protein foods to pair with protein, not to eat alone:** gari soakings (add milk and groundnuts, ~12 g, better paired with eggs), plain koko, bread alone, indomie alone (add 2 eggs, ~15 g), fried yam/plantain chips, kelewele, bofrot, pie, chips.

**Protein boosters to keep in your room:** eggs, canned sardines/mackerel/tuna, milk powder, dried anchovy/"abobi" or shrimp powder (stir 1-2 tbsp into stews and soups for +5-10 g), groundnuts, soya chunks, cooked beans.

### 2.4 Protein checklist (the default daily view)

1 **protein point ≈ 20 g protein.** The daily target is protein_target / 20, rounded. **For this user that is 7 points.** Tap a tile to tick a point.

| 1 point (≈ 20 g) | ½ point (≈ 10 g) |
|---|---|
| 3 eggs | 1-2 eggs |
| 1 tin sardines/mackerel/tuna | 1½ tbsp abobi or shrimp powder |
| 1 palm (~100 g) chicken, goat, beef, fish | 1 cup cooked beans (~13 g) |
| ½ medium tilapia | 250 ml milk / 3 tbsp milk powder |
| 3 sticks khebab (≈ 1.5) | 200 ml plain yoghurt |
| 100 g wagashi | 3 koose |
| 1 scoop whey | 30-40 g groundnuts |

Other checklist rows (all yes/no, no counting):

- 💧 Water: X sachets (from the water formula)
- 🥬 Vegetables or fruit with at least 2 meals
- 🚶 Steps target reached
- 😴 7+ hours of sleep last night
- 🥤 No sugary drinks today, or 1 max

A "good day" is reaching **protein ≥ protein_min (6 of 7 points) plus 3 of the other 5 rows.**

### 2.5 Student-budget tips

- **Eggs by the crate** and **beans in bulk** are the cheapest protein per cedi. Cook a pot of beans and boil 6-10 eggs on Sunday.
- Canned fish (sardines, mackerel) costs about the same as a fried-fish portion and gives more protein. Keep 3-4 tins in your room.
- Milk powder sachets turn koko, oats, gari and tea into protein sources.
- When buying food, **spend the extra cedi on an extra egg or fish, not extra gari, spaghetti or fried plantain.**
- Soya chunks and dried anchovies are very cheap ways to add protein to stews.
- Share a big tilapia or a full chicken with a friend.
- Supplements are optional. If money allows, **creatine monohydrate 3-5 g/day** is the best-supported cheap supplement for strength and muscle (ISSN creatine stand, Kreider 2017; Examine.com). Whey is a convenience, not a requirement. Skip fat burners and "mass gainers".

---

## 3. Progress tracking

### 3.1 Weigh-in protocol

- **When:** every morning (or at least 3 mornings a week), after the toilet, before food or water, in the same clothing (or none), on the same scale on a hard, flat floor.
- **What the app shows:** the **7-day rolling average**, the weekly change in that average, and a trend line. It does not highlight daily numbers. Daily weight can swing 0.5-2 kg from salt (e.g. shito, soups), carbs (big kenkey/banku nights), water, bowel content and heat. Frequent self-weighing with trend feedback is linked to better weight loss (Burke 2011; Zheng 2015).
- **Minimum data:** a weekly average needs ≥ 3 weigh-ins. Otherwise show "not enough data".
- Copy: *"Your weight bounces day to day. Only the weekly average matters."*

### 3.2 Waist

- Measure every week (same day as the weekly review). Use a tape at the **navel**, standing relaxed, at the end of a normal breath out, and take 2 readings and average them.
- Men: WHO > 94 cm = increased risk, > 102 cm = substantially increased risk. A waist-to-height ratio < 0.5 (Ashwell 2016) is a good long-term target, which is < 86 cm at 172 cm.
- **During a recomp, waist is often a better signal than weight.** Muscle gain can hide fat loss on the scale.

### 3.3 Progress photos (optional, opt-in)

- Every 4 weeks: front, side and back, same spot, same lighting, same time of morning, relaxed pose.
- Store only in app-private storage, never in the public gallery. Offer a PIN/biometric lock. A side-by-side compare view is very motivating at weeks 8-12.

### 3.4 Strength log as progress

- Show "first session vs now" on 4-5 anchor lifts (leg press, chest press or bench, lat pulldown, shoulder press, Romanian deadlift/goblet squat). Beginners often gain strength 20-50%+ in 12 weeks, mostly from better nerve-muscle coordination early on. This keeps motivation up when the scale stalls.

### 3.5 Weekly check-in logic (same weekday each week)

Let `rate = (avg_this_week − avg_last_week) / avg_last_week × 100` (% per week). Use the 2-week average of `rate` once 3 or more weeks of data exist. **Ignore weeks 1-2** for adjustments, because water and glycogen loss inflate them.

| Situation (for ≥ 2 consecutive check-ins) | Interpretation | Action |
|---|---|---|
| Loss 0.5-1.0%/wk | On track | Keep going 🎉 |
| Loss > 1.0%/wk after week 3 | Too fast; risks muscle, energy and adherence | Add +150 kcal (1 extra protein snack) |
| Loss 0.25-0.5%/wk | Slow but fine | Keep going. If waist is not dropping either, add +1,000 steps |
| Loss < 0.25%/wk **and** waist flat for **3 weeks** | Plateau | First check adherence (protein points, portion sizes, drinks). If adherence is good: −150 kcal **or** +2,000 steps (one change at a time) |
| Weight flat but waist ↓ and strength ↑ | Recomposition is working | **No change.** Show a "the scale is lying" explainer |
| Weight up > 0.5%/wk for 2 weeks | Over target | Review portions/drinks, then −150 kcal |
| Felt exhausted, sleep poor, strength dropping for 2+ weeks | Too aggressive or life stress | +150-200 kcal, prioritise sleep |

- **Limits:** never set calories below the floor, never change by more than 200 kcal per adjustment, and allow at most 1 adjustment every 2 weeks.
- **After 12 weeks of dieting:** offer an optional 1-2-week "maintenance break" at TDEE, which helps adherence (ISSN body-composition stand).
- **Recalculate** BMR/TDEE/protein every 4 kg lost.

---

## 4. Motivation and adherence

### 4.1 Streaks that forgive

- **Weekly streak, not daily.** A week "counts" if ≥ planned_days − 1 sessions are done (2 of 3 for this user). Daily lifting streaks are unrealistic and punish rest days.
- **Grace tokens:** earn 1 "rest pass" per 4 completed weeks (max 2 banked). A pass auto-saves a missed week (exams, malaria, travel).
- **"Never miss twice" rule:** a single missed session shows a gentle nudge, not a broken streak.
- **Pause mode:** for illness or exams. It freezes streaks and reminders for up to 3 weeks.
- Habit tracker rows (protein, water, steps, sleep) count toward a **"4 of 5 days" weekly badge**, not perfect days.

### 4.2 Habit formation built into the app

- **Habits take time:** Lally et al. (2010) found a median of 66 days (range 18-254) for a habit to become automatic. The app says: *"Weeks 1-8 run on willpower and plans; after ~2 months it gets easier."*
- **If-then plans** (implementation intentions; Gollwitzer & Sheeran 2006) at onboarding: *"After my [last lecture on Mon/Wed/Fri], I will walk to the gym."* Show this sentence on the home screen.
- **Lower the friction:** a "pack your gym bag" reminder the night before (towel, 1.5 L water bottle, phone charged, earphones). Note that the session is fully planned in the app.
- **Minimum viable session:** if the user is short on time or energy, offer a 20-minute version (warm-up + the first 2 exercises). Showing up keeps the habit going.
- **Self-monitoring:** weekly summary card (sessions, protein days, average weight, waist).
- **Identity framing:** "You're someone who trains", plus milestones that reward consistency over weight.

### 4.3 Soreness (DOMS)

- Expect soreness 24-72 h after the first 1-2 weeks of sessions, especially legs. It peaks at 24-48 h (Cheung 2003). The repeated-bout effect means it gets much milder by week 3.
- To reduce it: week 1 uses only 2 sets per exercise and stops 3-4 reps short of failure. Then do easy walking, normal protein and sleep.
- **Normal:** dull ache, stiffness, tenderness when pressed, improves with movement.
- **Not normal (see section 5):** sharp or joint pain, swelling, pain that worsens over 3+ days, or **dark "cola" urine with extreme muscle pain** (possible rhabdomyolysis, which needs urgent medical care).

### 4.4 Sleep

- 7-9 h/night for adults (National Sleep Foundation, Hirshkowitz 2015). Poor sleep raises hunger and lowers training quality, and in dieting studies a larger share of the weight lost came from lean mass.
- Tips: same wake time daily, phone away 30 min before bed, a fan or open window for heat, avoid big caffeine (coffee, energy drinks) after 3 pm, and plan around exam all-nighters.

### 4.5 What to expect, weeks 1-12 (realistic, for this profile)

| Weeks | Scale | Body | Strength and feel |
|---|---|---|---|
| 1-2 | −1 to −2.5 kg (mostly water and glycogen) | Feels "tighter" | Learning the machines and form. DOMS. Weights feel awkward. That's normal |
| 3-4 | −0.4 to −0.8 kg/week | Waist −1 to −3 cm in total | Strength up quickly (neural gains), often +10-20% on machines. Soreness fades |
| 5-8 | −0.4 to −0.7 kg/week; some flat weeks are normal | Clothes fit looser. Waist −3 to −6 cm total | Steady rep and weight increases most weeks |
| 9-12 | −0.3 to −0.6 kg/week | Visible change in photos. Waist −5 to −8 cm total | Many lifts +30-50% vs week 1. First plateau on some lifts, which is when the programme varies reps |
| **12-week total** | **~ −6 to −10 kg** (about 6-10% of body weight) | Real muscle gain likely (~1-2 kg) hidden under the fat loss | Confident with the whole gym |

Show this as a timeline card at onboarding and again at weeks 4, 8 and 12. Emphasise that **losing 5-10% of body weight improves blood pressure, blood sugar and blood lipids** (clinically meaningful).

---

## 5. Safety screen

### 5.1 PAR-Q+ style onboarding questions

These are paraphrased from the PAR-Q+ (Warburton et al.; 2023 version at eparmedx.com). Link to the official form. Answering **YES** to any of them gives the message: *"Please talk to a doctor (e.g. University of Ghana Hospital, Legon) before starting, or complete the full PAR-Q+ follow-up. You can still browse the app."* After that, ask the user to tick "I've been cleared by a doctor" to unlock the programme. Re-ask every 12 months, or whenever the user reports a new condition.

1. Has a doctor ever told you that you have a heart condition **or** high blood pressure?
2. Do you feel pain in your chest at rest, during daily activities, or when you are physically active?
3. In the past 12 months, have you lost balance because of dizziness or lost consciousness? (Answer NO if the dizziness came only from hard breathing during vigorous exercise.)
4. Have you been diagnosed with another chronic medical condition (e.g. diabetes, asthma, kidney disease, sickle cell disease)?
5. Are you currently taking prescribed medicine for a chronic medical condition?
6. Do you currently have, or have you had in the past 12 months, a bone, joint or soft-tissue (muscle, ligament, tendon) problem that could get worse with more activity? (Answer NO if it no longer limits you.)
7. Has a doctor ever said you should only do medically supervised physical activity?

**Ghana-relevant extra checks.** These show advice, not a block.

- 8. Do you have **sickle cell trait (AS) or sickle cell disease (SS/SC)**? It is common in Ghana. → Trait: hydrate well, avoid all-out efforts in heat, build intensity gradually over 3-4 weeks, and stop at unusual muscle pain or breathlessness. Disease: get a doctor's clearance first.
- 9. Have you had **malaria, typhoid or a fever** in the past 2 weeks? → Wait until 1-2 weeks after full recovery, then restart at 50% of the usual load.
- 10. Do you have **diabetes or take blood-sugar medicines**? → Carry a sweet snack, and don't train fasted.

### 5.2 Red-flag symptoms: stop the session immediately (red banner + "End workout" button)

- Chest pain, pressure or tightness, or pain spreading to the arm, jaw or back
- Severe breathlessness out of proportion to effort, or wheeze that doesn't settle
- Fainting, near-fainting, or sudden dizziness or confusion
- Racing or irregular heartbeat or palpitations
- Sudden severe headache, vision change, or weakness or numbness on one side
- Sharp joint pain, a "pop" with pain or swelling, or pain that changes how you move
- After a session: **dark/cola-coloured urine** with severe muscle pain or swelling (possible rhabdomyolysis), so go to hospital the same day

Emergency: **112** (Ghana national emergency) / **193** (National Ambulance Service). Show a button for the nearest facility, the University of Ghana Hospital, Legon. Let the user save an emergency contact.

### 5.3 Heat illness: Accra is hot and humid (NATA exertional heat illness statement, Casa 2015)

| Condition | Signs | Action in the app |
|---|---|---|
| Dehydration / heat cramps | Thirst, dark urine, muscle cramps, headache | Pause, drink water/ORS, move to shade or a fan |
| **Heat exhaustion** | Heavy sweating, cold/clammy skin, dizziness, nausea, weakness, fast weak pulse, headache | **Stop training.** Move to a cool place, lie down with legs up, sip water/ORS, and loosen clothing. Get help if there's no improvement in 30 min |
| **Heat stroke: EMERGENCY** | Confusion, slurred speech, strange behaviour, collapse, hot skin (may stop sweating), seizure, temperature ≥ 40 °C | **Call 112/193.** Cool aggressively right away with cold water or ice on the body and fan, while waiting for help |

**Prevention tips** (rotate on the pre-workout screen):

- Train in the cooler parts of the day where possible.
- Drink 400-600 ml in the 2 hours before.
- Bring a 1-1.5 L bottle.
- Wear light, breathable clothing.
- Take extra rest between sets if the gym is hot.
- Be extra careful in the first 2 weeks (heat acclimatisation takes ~10-14 days).
- Take care after illness or poor sleep, and with alcohol the night before.

---

## 6. Achievements and milestones

Design rules:

- Reward **consistency first**, strength second, and body change third. Body change is partly outside your control.
- Never reward rapid weight loss alone.
- Strength milestones use **logged load**. For machines, include an editable "sled/carriage weight" setting, since sled weights differ between machines (a typical leg-press sled is 25-50 kg).
- The "ankle machine" is ambiguous, so **no milestone depends on it.**

**Consistency**

- **Akwaaba**: first session completed
- **First full week**: all sessions of week 1 (e.g. Push, Pull, Legs)
- **10 sessions**, **25**, **50**, **100** ("Centurion")
- **4-week streak**, **12-week streak** ("One Semester Strong")
- **Exam Season Survivor**: kept the weekly streak through an exam period, with pause mode allowed
- **Harmattan Hero** (Dec-Feb) and **Rainy Season Regular** (Apr-Jul): 8 weeks of training in that season
- **Early Bird**: 5 sessions started before 08:00
- **Comeback**: returned within 7 days after a missed week (rewards restarting, not perfection)

**Strength (beginner-realistic, scaled to body weight where sensible)**

- **Leg press = body weight** (95 kg total incl. sled), then **1.5× body weight**
- **First plate bench**: barbell or Smith bench with 60 kg (20 kg bar + 20 kg plate each side)
- **Chest press machine: 50% body weight × 8**
- **Lat pulldown: 50% body weight × 10**, then **75% body weight × 8**
- **Romanian deadlift: 60 kg × 8**, then **body weight × 5**
- **Goblet squat with a 20 kg dumbbell × 10**
- **Dumbbell row: 25 kg × 10 each arm**
- **Shoulder press machine: 40% body weight × 8**
- **Personal record (PR)**: any lift beats its previous best (repeatable, with a small celebration)
- **Strength +25% / +50%** on the anchor lifts vs week 1

**Body and health** (based on the 7-day average, never a single weigh-in)

- **−2.5 kg**, **−5 kg**, **−10 kg**
- **−5% of body weight** (≈ 4.75 kg) and **−10% of body weight**: "clinically meaningful" badges, with an explainer on the health benefits
- **Waist −5 cm**, **Waist −10 cm**, **Waist under 102 cm**, **Waist under 94 cm**, **Waist-to-height < 0.5**
- **BMI under 30**: shown softly, not as a primary goal
- **Recomp Detective**: weight flat but waist down 2+ cm over 4 weeks

**Habits**

- **Protein Pro**: protein points reached on 5 of 7 days, then for 4 weeks in a row
- **Hydrated in the Heat**: water target reached on 7 of 7 days
- **Stepper**: average ≥ 8,000 steps for a week, then 10,000
- **Sleep Champion**: 7+ h average for a week
- **Cardio Starter**: 20 min of continuous bike/treadmill. **Cardio Builder**: 30 min

---

## 7. Contextual tips (shown in the app; the full list is in the JSON)

Keys: `rest_timer_tips`, `pre_workout`, `warm_up`, `during_workout_heat`, `post_workout`, `daily_nutrition`, `hydration`, `sleep`, `soreness`, `missed_session`, `plateau`, `weigh_in`, `gym_etiquette`, `budget`, `safety`. Rotate tips randomly within a key, and don't repeat the same tip within 7 days.

---

## References

1. Mifflin MD, St Jeor ST, et al. A new predictive equation for resting energy expenditure in healthy individuals. *Am J Clin Nutr*. 1990;51(2):241-247.
2. Frankenfield D, Roth-Yousey L, Compher C. Comparison of predictive equations for resting metabolic rate in healthy nonobese and obese adults: a systematic review. *J Am Diet Assoc*. 2005;105(5):775-789.
3. Jäger R, et al. ISSN position stand: protein and exercise. *J Int Soc Sports Nutr*. 2017;14:20.
4. Aragon AA, et al. ISSN position stand: diets and body composition. *J Int Soc Sports Nutr*. 2017;14:16.
5. Kerksick CM, et al. ISSN position stand: nutrient timing. *J Int Soc Sports Nutr*. 2017;14:33.
6. Kreider RB, et al. ISSN position stand: safety and efficacy of creatine supplementation. *J Int Soc Sports Nutr*. 2017;14:18.
7. Helms ER, Aragon AA, Fitschen PJ. Evidence-based recommendations for natural bodybuilding contest preparation: nutrition and supplementation. *J Int Soc Sports Nutr*. 2014;11:20.
8. Morton RW, et al. A systematic review, meta-analysis and meta-regression of the effect of protein supplementation on resistance training-induced gains in muscle mass and strength. *Br J Sports Med*. 2018;52(6):376-384.
9. Longland TM, et al. Higher compared with lower dietary protein during an energy deficit combined with intense exercise promotes greater lean mass gain and fat mass loss. *Am J Clin Nutr*. 2016;103(3):738-746.
10. Barakat C, et al. Body recomposition: can trained individuals build muscle and lose fat at the same time? *Strength Cond J*. 2020;42(5):7-21.
11. Hall KD. What is the required energy deficit per unit weight loss? *Int J Obes*. 2008;32(3):573-576.
12. Examine.com. Protein intake guide and creatine monograph (accessed 2026). examine.com
13. FAO/INFOODS. *West African Food Composition Table / Table de composition des aliments d'Afrique de l'Ouest* (Vincent A, et al.). FAO, Rome, 2019/2020.
14. USDA FoodData Central (for canned fish, eggs, poultry and dairy values). fdc.nal.usda.gov
15. Ghana Food-Based Dietary Guidelines. Ministry of Food and Agriculture / Ghana Health Service with FAO, 2023. The Ghana FDA regulates food safety and labelling; check product labels for packaged foods (milk powder, canned fish, yoghurt).
16. Bull FC, et al. WHO 2020 guidelines on physical activity and sedentary behaviour. *Br J Sports Med*. 2020;54:1451-1462.
17. Paluch AE, et al. Daily steps and all-cause mortality: a meta-analysis of 15 international cohorts. *Lancet Public Health*. 2022;7(3):e219-e228.
18. EFSA Panel on Dietetic Products. Scientific opinion on dietary reference values for water. *EFSA J*. 2010;8(3):1459. Institute of Medicine. *DRIs for Water, Potassium, Sodium, Chloride and Sulfate*. 2005.
19. Sawka MN, et al. ACSM position stand: exercise and fluid replacement. *Med Sci Sports Exerc*. 2007;39(2):377-390. McDermott BP, et al. NATA position statement: fluid replacement for the physically active. *J Athl Train*. 2017;52(9):877-895.
20. Casa DJ, et al. NATA position statement: exertional heat illnesses. *J Athl Train*. 2015;50(9):986-1000.
21. Warburton DER, Jamnik V, Bredin SSD, Gledhill N. The Physical Activity Readiness Questionnaire for Everyone (PAR-Q+) and ePARmed-X+. *Health Fit J Can*. 2011;4(2):3-23. Current form: eparmedx.com (2023).
22. WHO. *Waist circumference and waist-hip ratio: report of a WHO expert consultation*. Geneva, 2008. Ashwell M, Gibson S. Waist-to-height ratio as an indicator of early health risk. *BMJ Open*. 2016;6:e010159.
23. Lally P, et al. How are habits formed: modelling habit formation in the real world. *Eur J Soc Psychol*. 2010;40(6):998-1009.
24. Gollwitzer PM, Sheeran P. Implementation intentions and goal achievement: a meta-analysis. *Adv Exp Soc Psychol*. 2006;38:69-119.
25. Burke LE, Wang J, Sevick MA. Self-monitoring in weight loss: a systematic review. *J Am Diet Assoc*. 2011;111(1):92-102. Zheng Y, et al. Self-weighing in weight management: a systematic literature review. *Obesity*. 2015;23(2):256-265.
26. Cheung K, Hume P, Maxwell L. Delayed onset muscle soreness: treatment strategies and performance factors. *Sports Med*. 2003;33(2):145-164.
27. Hirshkowitz M, et al. National Sleep Foundation's sleep time duration recommendations. *Sleep Health*. 2015;1(1):40-43.
28. Precision Nutrition. Hand-portion method / "Calorie Control Guide".
29. Harris KM, et al. Sudden death during exertion in people with sickle cell trait (exertional collapse literature); ACSM/NCAA sickle cell trait guidance.
