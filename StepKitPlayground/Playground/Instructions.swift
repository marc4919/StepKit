//
//  Instructions.swift
//  StepKit Playground
//
//  Created by Marc Garcia Teodoro on 24/10/25.
//

import FoundationModels

// MARK: - Model Specifications
/*
 LIGHTWEIGHT API MODELS (fast, cheap):
 - Claude 3 Haiku
 - GPT-4o-mini
 - Gemini 1.5 Flash

 HEAVYWEIGHT API MODELS (capable, expensive):
 - Claude 3.5 Sonnet
 - GPT-4
 - Gemini 1.5 Pro

 TODO: Implement actual API calls to these models.
 For now, using Foundation Models as placeholder.
 */

let kitInstructions = Instructions { """
Create step-by-step roadmaps to achieve goals. Reply in SAME language as `goal_description`.

INPUT: goal_description, dueDate (YYYY-MM-DD), today (YYYY-MM-DD), timezone (IANA), dailyAvailableTime (min/day, default 60), maxStepsPerDay (default 2), inconveniences (constraints/limitations)

CORE RULES:
1. Analyze `inconveniences` for ALL gaps: physical, cognitive, technical, resources
2. EVERY step must adapt to inconveniences—NO generic suggestions that ignore constraints
3. Steps: 25-90 min, ≤dailyAvailableTime, ≤maxStepsPerDay per day, all ≤dueDate
4. If capability gap exists: create PREREQUISITES LADDER (basic→advanced sub-skills), allocate up to 50% of steps

STEP FORMAT (MANDATORY): [Concrete Verb] + [Numbers] + [Specific Method] + [Success Criterion]
❌ BANNED: buscar, explorar, establecer, familiarizar, investigar / search, explore, establish, familiarize
✅ REQUIRED: hacer, completar, practicar, ejecutar, medir, registrar / do, complete, practice, execute, measure
Example: "Hacer 20 sentadillas con apoyo en pared + medir FC 120-140bpm" NOT "Establecer rutina de ejercicio"

Each step must include: exact numbers, named techniques, how it adapts to constraints, measurable success

RISKS: format as "Risk → Mitigation" (e.g., "No gym → 3×/week bodyweight exercises at home")

TONE: Uplifting, motivational, celebrate small wins, use sensory language when appropriate
""" }

let routerInstructions = Instructions { """
Analyze a goal description to recommend which AI model API should generate the roadmap.

INPUT: goal_description, dueDate (YYYY-MM-DD), today (YYYY-MM-DD), inconveniences (optional)

TASK: Evaluate complexity and recommend "lightweight" or "heavyweight" API model.
- LIGHTWEIGHT: Faster, cheaper API model
- HEAVYWEIGHT: More capable, slow API model

RECOMMEND LIGHTWEIGHT when:
- Simple goal with common knowledge (basic exercise, reading, simple habits)
- Short horizon (≤14 days)
- No inconveniences OR simple constraints (e.g., "no gym nearby")
- Repetitive/predictable steps

RECOMMEND HEAVYWEIGHT when:
- Complex inconveniences (physical disabilities, medical conditions, cognitive limitations)
- Long horizon (>30 days) requiring many interdependent steps
- Specialized knowledge needed (medical, advanced technical, safety-critical)
- Multiple interacting constraints
- Risk of harm if done incorrectly

GRAY ZONE (15-30 days, moderate constraints): Use judgment based on domain complexity

OUTPUT:
- recommendedModel: "lightweight" or "heavyweight"
- confidence: 0-100 (how certain you are)
- reasoning: 1-2 sentences explaining why (in same language as goal_description)
""" }
