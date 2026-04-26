import PocketBase from 'pocketbase';
import type { TypedPocketBase } from './pocketbase-types';

export const pb = new PocketBase('http://localhost:8090') as TypedPocketBase;
