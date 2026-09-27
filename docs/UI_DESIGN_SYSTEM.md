# PennySprout UI Design System

Status: **LOCKED BETA TOKENS AND COMPONENT RULES**

The direction is calm, encouraging and trustworthy: a practical family tool with warmth, not a cartoon game or banking dashboard.

## 1. Color tokens

| Token | Hex | Use |
|---|---|---|
| `canvas` | `#FBF8F1` | Main background |
| `surface` | `#FFFFFF` | Cards, sheets and inputs |
| `surfaceMuted` | `#F1EDE4` | Grouped/disabled background |
| `ink` | `#20312B` | Primary text |
| `inkMuted` | `#66736E` | Secondary text |
| `border` | `#D9DED9` | Dividers and input borders |
| `primary` | `#2F7D5C` | Primary actions and active navigation |
| `primaryPressed` | `#246348` | Pressed primary action |
| `primarySoft` | `#DCEDE4` | Selected/supporting background |
| `accent` | `#D4A72C` | Rewards and highlighted progress |
| `success` | `#287A4B` | Approved/success |
| `warning` | `#A15C08` | Pending/caution |
| `error` | `#B83A3A` | Rejected/destructive/error |
| `info` | `#2E6E9E` | Informational/offline status |
| `overlay` | `#10201A99` | Modal scrim |

All foreground/background combinations must meet WCAG AA. Status always includes an icon/text label, never color alone.

## 2. Typography

Use the Android system font (Roboto) to avoid font loading and licensing dependencies.

| Style | Size/line | Weight |
|---|---:|---:|
| Display | 32/38 | 700 |
| Title 1 | 24/30 | 700 |
| Title 2 | 20/26 | 600 |
| Body | 16/24 | 400 |
| Body strong | 16/24 | 600 |
| Supporting | 14/20 | 400 |
| Label | 14/18 | 600 |
| Caption | 12/16 | 500 |
| Money large | 28/34 | 700; tabular numerals |

Respect system font scaling. No essential text may be truncated at 200% scale.

## 3. Layout tokens

- Spacing scale: `4, 8, 12, 16, 24, 32, 40`.
- Screen horizontal padding: 16; tablet behavior is irrelevant to approved scope but layouts may cap content width naturally.
- Minimum touch target: 44×44.
- Input/button height: 48 minimum.
- Corner radii: 8 for inputs, 12 for cards, 16 for sheets; avoid fully rounded containers except compact status tags.
- Elevation: use borders first; one subtle modal/floating elevation only.
- Dividers are 1 physical pixel where supported.

## 4. Component rules

- One filled primary action per screen/section.
- Secondary actions use outlined or text treatment.
- Destructive actions use error color and confirmation; never visually compete with primary action until invoked.
- Cards group related content only; do not turn every row/metric into a card.
- Money cards show label, amount and a one-line explanation.
- Status tags are limited to Pending, Approved, Rejected, Active, Inactive and Offline.
- Forms use persistent labels, helper/error text and appropriate keyboards.
- Lists use deterministic rows and dividers; long histories paginate.
- Empty states use a real icon, concise explanation and one relevant action.
- Skeletons are optional only for initial content geometry; use labelled progress when action status matters.

## 5. Motion

- Use platform-standard navigation and sheet transitions.
- Press feedback is immediate opacity/color change.
- Balance changes may use a single 200–250 ms fade/count transition after server confirmation.
- Respect reduced-motion settings.
- No confetti, looping animation, parallax or decorative motion in beta.

## 6. Icons and imagery

Use the Expo-compatible icon set already included by the scaffold; do not add an icon package. Icons accompany labels for ambiguous actions. Do not use emoji as icons.

The beta app icon/splash may use a simple sprout emerging from a circular coin form in `primary` and `accent`. Public brand assets remain gated by trademark/brand approval and do not block functional implementation.

## 7. Required component inventory

`Screen`, `TopBar`, `BottomTabs`, `Button`, `IconButton`, `TextField`, `PasswordField`, `MoneyField`, `SelectField`, `DateField`, `RadioGroup`, `StatusTag`, `TaskRow`, `ApprovalRow`, `MoneySummary`, `HistoryRow`, `EmptyState`, `ErrorState`, `OfflineBanner`, `ConfirmationSheet`, `ReasonSheet`, `Toast`, and `AccessibleProgress`.

Each component documents variants, disabled/loading/error behavior, accessibility name/role/state and test ID only where semantic queries are insufficient.
