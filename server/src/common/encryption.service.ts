import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'crypto';

@Injectable()
export class EncryptionService {
  private readonly logger = new Logger(EncryptionService.name);
  private readonly algorithm = 'aes-256-gcm';
  private readonly keyLength = 32;
  private readonly ivLength = 16;
  private readonly tagLength = 16;
  private readonly masterKey: Buffer;

  constructor(private readonly config: ConfigService) {
    const key = this.config.get<string>('ENCRYPTION_KEY');
    if (!key) {
      this.logger.warn('ENCRYPTION_KEY not set - using default (INSECURE!)');
      this.masterKey = crypto.scryptSync('default-key-change-me', 'salt', this.keyLength);
    } else {
      this.masterKey = Buffer.from(key, 'hex');
      if (this.masterKey.length !== this.keyLength) {
        throw new Error(`ENCRYPTION_KEY must be ${this.keyLength * 2} hex chars`);
      }
    }
  }

  encrypt(plaintext: string): string {
    const iv = crypto.randomBytes(this.ivLength);
    const cipher = crypto.createCipheriv(this.algorithm, this.masterKey, iv);
    
    let encrypted = cipher.update(plaintext, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    
    const tag = cipher.getAuthTag();
    
    return iv.toString('hex') + ':' + tag.toString('hex') + ':' + encrypted;
  }

  decrypt(ciphertext: string): string {
    const parts = ciphertext.split(':');
    if (parts.length !== 3) {
      throw new Error('Invalid encrypted format');
    }
    
    const iv = Buffer.from(parts[0], 'hex');
    const tag = Buffer.from(parts[1], 'hex');
    const encrypted = parts[2];
    
    const decipher = crypto.createDecipheriv(this.algorithm, this.masterKey, iv);
    decipher.setAuthTag(tag);
    
    let decrypted = decipher.update(encrypted, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    
    return decrypted;
  }

  encryptBytes(data: Buffer): Buffer {
    const iv = crypto.randomBytes(this.ivLength);
    const cipher = crypto.createCipheriv(this.algorithm, this.masterKey, iv);
    
    const encrypted = Buffer.concat([cipher.update(data), cipher.final()]);
    const tag = cipher.getAuthTag();
    
    return Buffer.concat([iv, tag, encrypted]);
  }

  decryptBytes(data: Buffer): Buffer {
    const iv = data.subarray(0, this.ivLength);
    const tag = data.subarray(this.ivLength, this.ivLength + this.tagLength);
    const encrypted = data.subarray(this.ivLength + this.tagLength);
    
    const decipher = crypto.createDecipheriv(this.algorithm, this.masterKey, iv);
    decipher.setAuthTag(tag);
    
    return Buffer.concat([decipher.update(encrypted), decipher.final()]);
  }

  generateKey(): string {
    return crypto.randomBytes(this.keyLength).toString('hex');
  }

  hash(data: string): string {
    return crypto.createHash('sha256').update(data).digest('hex');
  }
}
