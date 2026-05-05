# Mohaffez Web Design System

## Colors (DSColors)
| Token | Value | Usage |
|-------|-------|-------|
| primary | #0B7A75 | Brand teal — buttons, links, sidebar |
| primaryLight | #14B8A6 | Hover states, light accents |
| primaryDark | #095752 | Active states, dark accents |
| secondary | #D4A44A | Gold accent — highlights, badges |
| surface | #FFFFFF | Card backgrounds |
| surfaceMuted | #F8FAFB | Page background |
| surfaceSidebar | #0B7A75 | Sidebar background |
| border | #E5EDE9 | Default borders |
| borderHover | #D4DFD9 | Hover borders |
| text1 | #111827 | Primary text |
| text2 | #4B5563 | Secondary text |
| text3 | #9CA3AF | Placeholder/muted text |
| success | #2E8B57 | Success states |
| warning | #E67E22 | Warning states |
| error | #DC2626 | Error states |
| info | #3B82F6 | Info states |

## Spacing (DSSpacing)
| Token | Value |
|-------|-------|
| xs | 4px |
| sm | 8px |
| md | 12px |
| lg | 16px |
| xl | 24px |
| xxl | 32px |
| xxxl | 48px |
| xxxxl | 64px |

## Border Radius (DSRadius)
| Token | Value |
|-------|-------|
| sm | 6px |
| md | 10px |
| lg | 14px |
| xl | 20px |
| full | 9999px |
Use `DSRadius.lgAll` etc. for BorderRadius objects.

## Shadows (DSElevation)
| Token | Usage |
|-------|-------|
| DSElevation.sm | Subtle card lift |
| DSElevation.md | Dropdowns, popovers |
| DSElevation.lg | Modals, dialogs |

## Typography (DSText)
All methods take a BuildContext and auto-select font (IBM Plex Sans Arabic for RTL, Inter for LTR).
| Method | Size | Weight |
|--------|------|--------|
| DSText.display(context) | 32 | Bold |
| DSText.h1(context) | 24 | Bold |
| DSText.h2(context) | 20 | SemiBold |
| DSText.h3(context) | 16 | SemiBold |
| DSText.body(context) | 14 | Regular |
| DSText.bodyMedium(context) | 14 | Medium |
| DSText.caption(context) | 12 | Regular |
| DSText.micro(context) | 11 | Medium |

## Breakpoints
| Name | Width |
|------|-------|
| mobile | < 640px |
| tablet | 640–1024px |
| desktop | 1024–1440px |
| wide | > 1440px |
Use: `Breakpoints.isDesktop(context)`, `Breakpoints.of(context) == Breakpoint.tablet`

## Rules
- NEVER use raw Colors.* — always DSColors.*
- NEVER use .withOpacity() — use .withValues(alpha: x)
- NEVER hardcode pixel values — use DSSpacing.* or DSRadius.*
- ALWAYS use DSText.* for typography (auto-selects RTL/LTR font)
