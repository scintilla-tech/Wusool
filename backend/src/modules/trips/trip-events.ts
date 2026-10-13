import { EventEmitter } from 'node:events';

export interface TripCompletedEvent {
  tenantId: string;
  tripId: string;
}

export interface AttendanceChangedEvent {
  tenantId: string;
  tripId: string | null;
  attendanceSessionId: string;
  direction: 'OUTBOUND' | 'RETURN';
  studentProfileId: string;
  studentUserId: string;
  intent: 'ATTENDING' | 'ABSENT';
}

export interface AttendanceClosedEvent {
  tenantId: string;
  tripId: string;
  attendanceSessionId: string;
  direction: 'OUTBOUND' | 'RETURN';
  closedAt: string;
}

/** In-process lifecycle events. A multi-instance deployment must replace this with a broker. */
export class TripEventBus {
  private readonly emitter = new EventEmitter();

  emitCompleted(event: TripCompletedEvent): void {
    this.emitter.emit('completed', event);
  }

  onCompleted(listener: (event: TripCompletedEvent) => void): () => void {
    this.emitter.on('completed', listener);
    return () => this.emitter.off('completed', listener);
  }

  emitAttendanceChanged(event: AttendanceChangedEvent): void {
    this.emitter.emit('attendanceChanged', event);
  }

  onAttendanceChanged(listener: (event: AttendanceChangedEvent) => void): () => void {
    this.emitter.on('attendanceChanged', listener);
    return () => this.emitter.off('attendanceChanged', listener);
  }

  emitAttendanceClosed(event: AttendanceClosedEvent): void {
    this.emitter.emit('attendanceClosed', event);
  }

  onAttendanceClosed(listener: (event: AttendanceClosedEvent) => void): () => void {
    this.emitter.on('attendanceClosed', listener);
    return () => this.emitter.off('attendanceClosed', listener);
  }
}
