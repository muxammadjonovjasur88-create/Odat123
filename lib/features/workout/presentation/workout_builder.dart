import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/workout.dart';

/// Editor for a structured set-based workout, used inside Add Goal for sport
/// tasks. Lets the user add ordered exercises (name, total reps, reps/set →
/// auto sets) each with a suggested-but-editable rest, plus the rest between
/// exercises. Emits the built [WorkoutPlan] via [onChanged] on every edit.
class WorkoutBuilder extends StatefulWidget {
  const WorkoutBuilder({super.key, required this.onChanged, this.initialPlan});

  final ValueChanged<WorkoutPlan> onChanged;

  /// When editing, pre-fills the builder with an existing plan's exercises.
  final WorkoutPlan? initialPlan;

  @override
  State<WorkoutBuilder> createState() => _WorkoutBuilderState();
}

class _WorkoutBuilderState extends State<WorkoutBuilder> {
  late final List<_ExerciseDraft> _drafts =
      (widget.initialPlan?.exercises.isNotEmpty ?? false)
      ? widget.initialPlan!.exercises.map(_ExerciseDraft.from).toList()
      : [_ExerciseDraft()];
  late final TextEditingController _betweenExercises = TextEditingController(
    text:
        '${widget.initialPlan?.restBetweenExercises ?? WorkoutPlan.suggestedRestBetweenExercises}',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void dispose() {
    for (final d in _drafts) {
      d.dispose();
    }
    _betweenExercises.dispose();
    super.dispose();
  }

  void _emit() {
    final exercises = _drafts.map((d) => d.build()).toList();
    final between =
        int.tryParse(_betweenExercises.text) ??
        WorkoutPlan.suggestedRestBetweenExercises;
    widget.onChanged(
      WorkoutPlan(exercises: exercises, restBetweenExercises: between),
    );
  }

  void _addExercise() {
    setState(() => _drafts.add(_ExerciseDraft()));
    _emit();
  }

  void _removeExercise(int i) {
    setState(() => _drafts.removeAt(i).dispose());
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _drafts.length; i++) ...[
          _ExerciseCard(
            index: i,
            draft: _drafts[i],
            canRemove: _drafts.length > 1,
            onChanged: _emit,
            onRemove: () => _removeExercise(i),
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed: _addExercise,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text('workout.add_exercise'.tr()),
        ),
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'workout.rest_between'.tr(),
                      style: AppTextStyles.label.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'workout.suggested_editable'.tr(),
                      style: AppTextStyles.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 92,
                child: AppInput(
                  label: 'workout.seconds'.tr(),
                  controller: _betweenExercises,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => _emit(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.index,
    required this.draft,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _ExerciseDraft draft;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sets = draft.sets;
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'workout.exercise_n'.tr(namedArgs: {'n': '${index + 1}'}),
                style: AppTextStyles.overline.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const Spacer(),
              if (canRemove)
                GestureDetector(
                  onTap: onRemove,
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: colors.textTertiary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          AppInput(
            label: 'workout.name'.tr(),
            controller: draft.name,
            hint: 'workout.name_hint'.tr(),
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppInput(
                  label: 'goal.total_reps'.tr(),
                  controller: draft.totalReps,
                  hint: '100',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppInput(
                  label: 'workout.reps_per_set'.tr(),
                  controller: draft.repsPerSet,
                  hint: '20',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) {
                    draft.refreshSuggestedRest();
                    onChanged();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  sets > 0
                      ? 'workout.sets_eq'.tr(namedArgs: {'sets': '$sets'})
                      : 'workout.enter_reps'.tr(),
                  style: AppTextStyles.label.copyWith(color: colors.primary),
                ),
              ),
              SizedBox(
                width: 110,
                child: AppInput(
                  label: 'workout.rest_sec'.tr(),
                  controller: draft.rest,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) {
                    draft.restEdited = true;
                    onChanged();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Mutable form state for one exercise.
class _ExerciseDraft {
  _ExerciseDraft() {
    rest.text = '${WorkoutExercise.suggestedRest(0)}';
  }

  /// Seeds the draft from a saved exercise (used when editing a workout).
  _ExerciseDraft.from(WorkoutExercise e) {
    name.text = e.name;
    totalReps.text = '${e.totalReps}';
    repsPerSet.text = '${e.repsPerSet}';
    rest.text = '${e.restSeconds}';
    restEdited = true; // keep the saved rest; don't auto-overwrite it
  }

  final name = TextEditingController();
  final totalReps = TextEditingController();
  final repsPerSet = TextEditingController();
  final rest = TextEditingController();

  /// Once the user edits rest, stop auto-overwriting it from the suggestion.
  bool restEdited = false;

  int get _total => int.tryParse(totalReps.text) ?? 0;
  int get _perSet => int.tryParse(repsPerSet.text) ?? 0;

  int get sets => (_total <= 0 || _perSet <= 0) ? 0 : (_total / _perSet).ceil();

  void refreshSuggestedRest() {
    if (restEdited) return;
    rest.text = '${WorkoutExercise.suggestedRest(_perSet)}';
  }

  WorkoutExercise build() => WorkoutExercise(
    name: name.text.trim(),
    totalReps: _total,
    repsPerSet: _perSet < 1 ? 1 : _perSet,
    restSeconds:
        int.tryParse(rest.text) ?? WorkoutExercise.suggestedRest(_perSet),
  );

  void dispose() {
    name.dispose();
    totalReps.dispose();
    repsPerSet.dispose();
    rest.dispose();
  }
}
