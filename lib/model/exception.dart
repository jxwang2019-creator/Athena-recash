enum FaceAuthFailure {
  cameraCaptureFailed('Failed to capture image', 'Camera error occurred'),
  noFaceDetected('No face found', 'Position your face in the frame'),
  multipleFaces('Multiple faces', 'Only one person should be visible'),
  faceTooSmall('Move closer', 'Face should fill more of the screen'),
  meshDetectionFailed('Face scan failed', 'Could not detect facial features'),
  eyesClosed('Eyes not visible', 'Please keep your eyes open'),
  headTilted('Face not straight', 'Look directly at the camera'),
  poorLighting('Lighting issue', 'Move to better lighting'),
  embeddingFailed('Processing error', 'Failed to create face profile'),
  timeout('Operation timed out', 'Please try again'),
  unknown('Technical issue', 'Something went wrong');

  final String title;
  final String instruction;

  const FaceAuthFailure(this.title, this.instruction);
}

class ProcessStep {
  final String name;
  final String failureHint;

  const ProcessStep(this.name, this.failureHint);
}

class FaceAuthException implements Exception {
  final FaceAuthFailure failure;
  final ProcessStep step;
  final String? debugDetails;

  FaceAuthException(this.failure, this.step, [this.debugDetails]);

  String get userMessage => '${step.name} failed: ${failure.title}\n${failure.instruction}';

  @override
  String toString() => '[${step.name}] ${failure.title}: ${debugDetails ?? ''}';
}