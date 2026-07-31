export type Role = 'admin' | 'patient';
export type Profile = { id: string; full_name: string; phone: string | null; birth_date: string | null; role: Role };
export type Questionnaire = { id: string; title: string; description: string | null; questions: Question[]; is_active: boolean };
export type Question = { id: string; text: string; options: { label: string; value: number }[] };
export type Assignment = { id: string; questionnaire_id: string; due_date: string | null; can_retake: boolean; status: string; questionnaire: Questionnaire };
