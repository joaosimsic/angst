import { Client, type ConnectConfig } from "ssh2";
import type { Config } from "./config.js";

export interface SshResult {
  stdout: string;
  stderr: string;
  exitCode: number;
}

export function sshExec(
  command: string,
  config: Config,
  timeout = 30000,
): Promise<SshResult> {
  return new Promise((resolve, reject) => {
    const conn = new Client();
    const result: SshResult = { stdout: "", stderr: "", exitCode: -1 };

    const timer = setTimeout(() => {
      conn.end();
      reject(new Error("SSH command timeout"));
    }, timeout);

    conn.on("ready", () => {
      conn.exec(command, (err, stream) => {
        if (err) {
          clearTimeout(timer);
          conn.end();
          reject(err);
          return;
        }

        stream.on("close", (code: number | null) => {
          clearTimeout(timer);
          conn.end();
          result.exitCode = code || 0;
          resolve(result);
        });

        stream.on("data", (data: Buffer) => {
          result.stdout += data.toString();
        });
        stream.stderr.on("data", (data: Buffer) => {
          result.stderr += data.toString();
        });
      });
    });

    conn.on("error", (err: Error) => {
      clearTimeout(timer);
      reject(err);
    });

    conn.connect({
      host: config.sshHost,
      port: config.sshPort,
      username: config.sshUser,
      agent: process.env.SSH_AUTH_SOCK,
      agentForward: true,
    } as ConnectConfig);
  });
}

export async function isSshReachable(config: Config): Promise<boolean> {
  try {
    await sshExec("echo ok", config, 5000);
    return true;
  } catch {
    return false;
  }
}
